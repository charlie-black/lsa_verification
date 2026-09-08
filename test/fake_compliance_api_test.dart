import 'package:flutter_test/flutter_test.dart';
import 'package:lsa_verification/controllers/verification_controller.dart';
import 'package:lsa_verification/models/verification_status.dart';
import 'package:lsa_verification/services/compliance_service.dart';
import 'package:lsa_verification/services/fake_compliance_api.dart';
import 'package:lsa_verification/services/friction_logger.dart';

VerificationController _controller() => VerificationController(
      complianceService: ComplianceService(
        client: FakeComplianceApi(latency: Duration.zero),
      ),
      frictionLogger: FrictionLogger(sink: (_) {}),
    );

void main() {
  group('FakeComplianceApi drives the three cases end-to-end', () {
    test('Case 1: PCC-2026-9901 + PRED-9982-XYZ → Success', () async {
      final c = _controller();
      c.consentCodeController.text = 'PCC-2026-9901';

      await c.submit();

      expect(c.state.status, VerificationStatus.success);
      expect(c.state.submitEnabled, isTrue);
      addTearDown(c.dispose);
    });

    test('right consent code but wrong predecessor_id → NOT success (fail-closed)',
        () async {
      final c = _controller();
      c.debugSetLineagePresent(present: false);
      final fake = FakeComplianceApi(latency: Duration.zero);
      final res = await fake.post(
        Uri.parse('https://x'),
        body:
            '{"predecessor_id":"WRONG","lsa_id":"LSA-7049","parent_consent_code":"PCC-2026-9901"}',
      );
      expect(res.body, contains('null'));
      addTearDown(c.dispose);
    });

    test('Case 2: orphan toggle clears predecessor_id → blocked, Quarantined',
        () async {
      final c = _controller();
      c.debugSetLineagePresent(present: false);
      c.consentCodeController.text = 'PCC-2026-9901';

      await c.submit();

      expect(c.predecessorId, isNull);
      expect(c.state.status, VerificationStatus.quarantined);
      expect(c.state.submitEnabled, isTrue);
      addTearDown(c.dispose);
    });

    test('Case 3: PCC-FAIL-500 → locked Quarantine with the compliance message',
        () async {
      final c = _controller();
      c.consentCodeController.text = 'PCC-FAIL-500';

      await c.submit();

      expect(c.state.status, VerificationStatus.quarantined);
      expect(c.state.message, 'Data Quarantined – Compliance Failure');
      expect(c.state.submitEnabled, isFalse);
      expect(c.consentCodeController.text, isEmpty);
      addTearDown(c.dispose);
    });

    test('Case 3: PCC-FAIL-NULL ({"status": null}) → same locked Quarantine',
        () async {
      final c = _controller();
      c.consentCodeController.text = 'PCC-FAIL-NULL';

      await c.submit();

      expect(c.state.status, VerificationStatus.quarantined);
      expect(c.state.message, 'Data Quarantined – Compliance Failure');
      expect(c.state.submitEnabled, isFalse);
      addTearDown(c.dispose);
    });

    test('unknown consent code cannot be confirmed → fail closed (Case 3)',
        () async {
      final c = _controller();
      c.consentCodeController.text = 'whatever';

      await c.submit();

      expect(c.state.status, VerificationStatus.quarantined);
      addTearDown(c.dispose);
    });
  });
}
