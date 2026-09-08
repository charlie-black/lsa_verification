enum VerificationStatus { idle, processing, quarantined, success }

extension VerificationStatusLabel on VerificationStatus {
  String get bannerText {
    switch (this) {
      case VerificationStatus.idle:
        return 'Idle';
      case VerificationStatus.processing:
        return 'Processing';
      case VerificationStatus.quarantined:
        return 'Quarantined (Fail-Closed)';
      case VerificationStatus.success:
        return 'Success';
    }
  }
}
