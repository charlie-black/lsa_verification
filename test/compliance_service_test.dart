import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsa_verification/exceptions/lineage_exception.dart';
import 'package:lsa_verification/services/compliance_service.dart';

void main() {
  group('ComplianceService fail-closed rules', () {
    test('Case 1: valid submission sends mandatory headers + body schema', () async {
      late http.Request captured;
      final service = ComplianceService(
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"status":"verified"}', 200);
        }),
      );

      final result = await service.verify(
        predecessorId: 'PRED-9982-XYZ',
        lsaId: 'LSA-7049',
        parentConsentCode: 'PCC-2026-9901',
      );

      expect(result['status'], 'verified');

      expect(captured.headers['content-type'], contains('application/json'));
      expect(
        captured.headers['x-trace-id'],
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
      expect(captured.headers['x-logic-hash'], matches(RegExp(r'^[0-9a-f]{64}$')));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.keys, containsAll(<String>[
        'predecessor_id',
        'lsa_id',
        'parent_consent_code',
        'timestamp_utc',
      ]));
      expect(body['predecessor_id'], 'PRED-9982-XYZ');
      expect(body['lsa_id'], 'LSA-7049');
      expect(body['parent_consent_code'], 'PCC-2026-9901');
      expect(
        body['timestamp_utc'] as String,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')),
      );
      expect(DateTime.tryParse(body['timestamp_utc'] as String)?.isUtc, isTrue);

      expect(body.keys.toList(),
          ['predecessor_id', 'lsa_id', 'parent_consent_code', 'timestamp_utc']);
    });

    test('Case 2: null predecessor_id throws LineageException, no network I/O', () async {
      var networkTouched = false;
      final service = ComplianceService(
        client: MockClient((_) async {
          networkTouched = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.verify(
          predecessorId: null,
          lsaId: 'LSA-7049',
          parentConsentCode: 'PCC-2026-9901',
        ),
        throwsA(isA<LineageException>()),
      );
      expect(networkTouched, isFalse);
    });

    test('Case 2: empty/whitespace predecessor_id also throws LineageException', () async {
      final service = ComplianceService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        service.verify(
          predecessorId: '   ',
          lsaId: 'LSA-7049',
          parentConsentCode: 'PCC-2026-9901',
        ),
        throwsA(isA<LineageException>()),
      );
    });

    test('Case 3: HTTP 500 surfaces ComplianceQuarantineException', () async {
      final service = ComplianceService(
        client: MockClient((_) async => http.Response('server error', 500)),
      );
      await expectLater(
        service.verify(
          predecessorId: 'PRED-9982-XYZ',
          lsaId: 'LSA-7049',
          parentConsentCode: 'PCC-2026-9901',
        ),
        throwsA(isA<ComplianceQuarantineException>()),
      );
    });

    test('Case 3: { "status": null } body surfaces ComplianceQuarantineException', () async {
      final service = ComplianceService(
        client: MockClient((_) async => http.Response('{"status": null}', 200)),
      );
      await expectLater(
        service.verify(
          predecessorId: 'PRED-9982-XYZ',
          lsaId: 'LSA-7049',
          parentConsentCode: 'PCC-2026-9901',
        ),
        throwsA(isA<ComplianceQuarantineException>()),
      );
    });

    test('Case 3: timeout / network failure surfaces ComplianceQuarantineException', () async {
      final service = ComplianceService(
        client: MockClient((_) async => throw const _Boom()),
      );
      await expectLater(
        service.verify(
          predecessorId: 'PRED-9982-XYZ',
          lsaId: 'LSA-7049',
          parentConsentCode: 'PCC-2026-9901',
        ),
        throwsA(isA<ComplianceQuarantineException>()),
      );
    });
  });
}

class _Boom implements Exception {
  const _Boom();
}
