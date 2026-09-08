import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../exceptions/lineage_exception.dart';

class ComplianceService {
  static const endpoint =
      'https://api.habotconnect.com/v1/compliance/verify';
  static const Duration requestTimeout = Duration(seconds: 10);

  final http.Client _client;
  final Uuid _uuid;

  ComplianceService({http.Client? client, Uuid? uuid})
      : _client = client ?? http.Client(),
        _uuid = uuid ?? const Uuid();

  Future<Map<String, dynamic>> verify({
    required String? predecessorId,
    required String lsaId,
    required String parentConsentCode,
  }) async {
    if (predecessorId == null || predecessorId.trim().isEmpty) {
      throw const LineageException();
    }

    final body = <String, dynamic>{
      'predecessor_id': predecessorId,
      'lsa_id': lsaId,
      'parent_consent_code': parentConsentCode,
      'timestamp_utc': _isoSeconds(DateTime.now()),
    };
    final encodedBody = jsonEncode(body);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-trace-id': _uuid.v4(),
      'x-logic-hash': sha256.convert(utf8.encode(encodedBody)).toString(),
    };

    late final http.Response response;
    try {
      response = await _client
          .post(Uri.parse(endpoint), headers: headers, body: encodedBody)
          .timeout(requestTimeout);
    } catch (_) {
      throw const ComplianceQuarantineException('Request failed or timed out');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ComplianceQuarantineException(
          'Server returned ${response.statusCode}');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ComplianceQuarantineException('Malformed response body');
    }

    if (decoded['status'] == null) {
      throw const ComplianceQuarantineException('Compliance status was null');
    }

    return decoded;
  }

  static String _isoSeconds(DateTime dt) =>
      '${dt.toUtc().toIso8601String().split('.').first}Z';

  void dispose() => _client.close();
}
