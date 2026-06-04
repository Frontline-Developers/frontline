enum PinStatus {
  loading,
  createPin,
  confirmPin,
  enterPin,
  bypassWarning,
  biometricSetup,
  unlocked,
  error,
}

class PinState {
  final PinStatus status;
  final List<int> digits;
  final String? confirmBuffer;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final String? errorMessage;

  const PinState({
    this.status = PinStatus.loading,
    this.digits = const [],
    this.confirmBuffer,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.errorMessage,
  });

  PinState copyWith({
    PinStatus? status,
    List<int>? digits,
    bool? biometricAvailable,
    bool? biometricEnabled,
    Object? confirmBuffer = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return PinState(
      status: status ?? this.status,
      digits: digits ?? this.digits,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      confirmBuffer: identical(confirmBuffer, _sentinel)
          ? this.confirmBuffer
          : confirmBuffer as String?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _sentinel = Object();
