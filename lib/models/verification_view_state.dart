import 'verification_status.dart';

class VerificationViewState {
  final VerificationStatus status;
  final String? message;
  final bool submitEnabled;

  const VerificationViewState({
    required this.status,
    this.message,
    this.submitEnabled = true,
  });

  factory VerificationViewState.initial() => const VerificationViewState(
        status: VerificationStatus.idle,
        submitEnabled: true,
      );

  VerificationViewState copyWith({
    VerificationStatus? status,
    String? message,
    bool? submitEnabled,
  }) {
    return VerificationViewState(
      status: status ?? this.status,
      message: message,
      submitEnabled: submitEnabled ?? this.submitEnabled,
    );
  }
}
