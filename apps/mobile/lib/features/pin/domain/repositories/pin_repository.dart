import '../entities/pin_state.dart';

abstract class PinRepository {
  Future<PinStatus> getInitialStatus();
  Future<bool> verifyPin(String pin);
  Future<void> savePin(String pin);
  Future<void> resetAll();
  Future<bool> isBiometricAvailable();
  Future<bool> getBiometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
}
