import 'dart:convert';

import 'package:http/http.dart' as http;

class FakeComplianceApi extends http.BaseClient {
  static const String validPredecessorId = 'PRED-9982-XYZ';
  static const String validConsentCode = 'PCC-2026-9901';

  final Duration latency;

  FakeComplianceApi({this.latency = const Duration(milliseconds: 400)});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(latency);

    final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    final consent = body['parent_consent_code'] as String? ?? '';
    final predecessor = body['predecessor_id'] as String? ?? '';

    final validSubmission =
        predecessor == validPredecessorId && consent == validConsentCode;

    final (int status, String payload) = switch (consent) {
      'PCC-FAIL-500' => (500, 'upstream compliance error'),
      'PCC-FAIL-NULL' => (200, '{"status": null}'),
      _ when validSubmission => (
          200,
          jsonEncode({
            'status': 'verified',
            'reference': 'CMP-${DateTime.now().millisecondsSinceEpoch}',
          }),
        ),
      _ => (200, '{"status": null}'),
    };

    return http.StreamedResponse(
      Stream.value(utf8.encode(payload)),
      status,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
