class LineageException implements Exception {
  final String message;
  const LineageException([this.message = 'predecessor_id is missing or invalid — orphan data blocked']);

  @override
  String toString() => 'LineageException: $message';
}

class ComplianceQuarantineException implements Exception {
  final String message;
  const ComplianceQuarantineException([this.message = 'Compliance check failed — data quarantined']);

  @override
  String toString() => 'ComplianceQuarantineException: $message';
}
