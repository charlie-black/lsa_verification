import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsa_verification/controllers/verification_controller.dart';
import 'package:lsa_verification/exceptions/lineage_exception.dart';
import 'package:lsa_verification/models/verification_status.dart';
import 'package:lsa_verification/services/compliance_service.dart';
import 'package:lsa_verification/services/friction_logger.dart';

VerificationController _controller(
  MockClient client, {
  String? predecessorId = VerificationController.systemPredecessorId,
}) {
  return VerificationController(
    complianceService: ComplianceService(client: client),
    frictionLogger: FrictionLogger(sink: (_) {}),
    predecessorId: predecessorId,
  );
}

void main() {
  group('VerificationController fail-closed rules', () {
    test('Case 1: valid submission → Success, button stays enabled', () async {
      final c = _controller(
        MockClient((_) async => http.Response('{"status":"verified"}', 200)),
      );
      c.consentCodeController.text = 'PCC-2026-9901';

      await c.submit();

      expect(c.state.status, VerificationStatus.success);
      expect(c.state.submitEnabled, isTrue);
      addTearDown(c.dispose);
    });

    test('Case 2: orphan lineage → LineageException thrown, network blocked, '
        'Quarantined, no purge, resubmittable', () async {
      var networkTouched = false;
      final c = _controller(
        MockClient((_) async {
          networkTouched = true;
          return http.Response('{"status":"verified"}', 200);
        }),
        predecessorId: null,
      );
      c.consentCodeController.text = 'PCC-2026-9901';

      await c.submit();

      expect(networkTouched, isFalse, reason: 'no socket on orphan data');
      expect(c.state.status, VerificationStatus.quarantined);
      expect(c.state.submitEnabled, isTrue, reason: 'Case 2 does not lock');
      expect(c.consentCodeController.text, 'PCC-2026-9901');
      expect(c.state.message, const LineageException().message);
      addTearDown(c.dispose);
    });

    test('Case 2: never reaches Processing (blocked immediately)', () async {
      final seen = <VerificationStatus>[];
      final c = _controller(
        MockClient((_) async => http.Response('{"status":"verified"}', 200)),
        predecessorId: null,
      );
      c.addListener(() => seen.add(c.state.status));

      await c.submit();

      expect(seen, [VerificationStatus.quarantined]);
      expect(seen, isNot(contains(VerificationStatus.processing)));
      addTearDown(c.dispose);
    });

    test('Case 3: null API response → purge, form reset, button LOCKED, message',
        () async {
      final c = _controller(
        MockClient((_) async => http.Response('{"status": null}', 200)),
      );
      c.consentCodeController.text = 'PCC-2026-9901';

      await c.submit();

      expect(c.state.status, VerificationStatus.quarantined);
      expect(c.state.message,
          VerificationController.quarantineFailureMessage);
      expect(c.state.message, 'Data Quarantined – Compliance Failure');
      expect(c.state.submitEnabled, isFalse, reason: 'submission locked');
      expect(c.consentCodeController.text, isEmpty, reason: 'form state reset');
      expect(c.lsaIdController.text, 'LSA-7049', reason: 'form state reset');
      expect(c.predecessorId, isNull, reason: 'volatile memory purged');

      await c.submit();
      expect(c.state.status, VerificationStatus.quarantined);

      c.resetSession();
      expect(c.state.status, VerificationStatus.idle);
      expect(c.state.submitEnabled, isTrue);
      expect(c.predecessorId, VerificationController.systemPredecessorId);
      addTearDown(c.dispose);
    });

    test('Case 3: HTTP 500 → same locked quarantine outcome', () async {
      final c = _controller(
        MockClient((_) async => http.Response('boom', 500)),
      );
      c.consentCodeController.text = 'PCC-2026-9901';

      await c.submit();

      expect(c.state.status, VerificationStatus.quarantined);
      expect(c.state.message,
          VerificationController.quarantineFailureMessage);
      expect(c.state.submitEnabled, isFalse);
      addTearDown(c.dispose);
    });

    test('emits Processing before the terminal state', () async {
      final seen = <VerificationStatus>[];
      final c = _controller(
        MockClient((_) async => http.Response('{"status":"verified"}', 200)),
      );
      c.addListener(() => seen.add(c.state.status));

      await c.submit();

      expect(seen, containsAllInOrder(
        [VerificationStatus.processing, VerificationStatus.success],
      ));
      addTearDown(c.dispose);
    });
  });
}
