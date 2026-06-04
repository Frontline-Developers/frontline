import '../../domain/entities/pin_state.dart';
import '../../domain/repositories/pin_repository.dart';
import '../datasources/pin_datasource.dart';

class PinRepositoryImpl implements PinRepository {
  final PinDatasource _datasource;

  const PinRepositoryImpl(this._datasource);

  @override
  Future<PinStatus> getInitialStatus() => _datasource.getInitialStatus();

  @override
  Future<bool> verifyPin(String pin) => _datasource.verifyPin(pin);

  @override
  Future<void> savePin(String pin) => _datasource.savePin(pin);

  @override
  Future<void> resetAll() => _datasource.resetAll();

  @override
  Future<bool> isBiometricAvailable() => _datasource.isBiometricAvailable();

  @override
  Future<bool> getBiometricEnabled() => _datasource.getBiometricEnabled();

  @override
  Future<void> setBiometricEnabled(bool enabled) =>
      _datasource.setBiometricEnabled(enabled);
}
