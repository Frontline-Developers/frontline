import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/datasources/pin_datasource.dart';
import '../../data/repositories/pin_repository_impl.dart';
import '../../domain/entities/pin_state.dart';
import '../../domain/repositories/pin_repository.dart';

final _pinDatasourceProvider = Provider<PinDatasource>(
  (_) => PinDatasourceImpl(
    storage: const FlutterSecureStorage(),
    localAuth: LocalAuthentication(),
  ),
);

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepositoryImpl(ref.watch(_pinDatasourceProvider)),
);

final pinNotifierProvider = NotifierProvider<PinNotifier, PinState>(
  PinNotifier.new,
);

class PinNotifier extends Notifier<PinState> {
  @override
  PinState build() {
    _initialize();
    return const PinState();
  }

  Future<void> _initialize() async {
    try {
      final repo = ref.read(pinRepositoryProvider);
      final status = await repo.getInitialStatus();
      final biometricAvailable = await repo.isBiometricAvailable();
      final biometricEnabled = biometricAvailable
          ? await repo.getBiometricEnabled()
          : false;

      state = state.copyWith(
        status: status,
        biometricAvailable: biometricAvailable,
        biometricEnabled: biometricEnabled,
      );

      if (status == PinStatus.enterPin &&
          biometricAvailable &&
          biometricEnabled) {
        promptBiometrics();
      }
    } catch (_) {
      // Storage read failed (corrupted keystore, revoked permissions, etc.).
      // Fall back to PIN creation so the user is never permanently locked out.
      state = state.copyWith(status: PinStatus.createPin);
    }
  }

  void appendDigit(int digit) {
    if (state.digits.length >= 6) return;
    if (state.status == PinStatus.unlocked) return;

    final updated = [...state.digits, digit];
    state = state.copyWith(digits: updated, errorMessage: null);

    if (updated.length == 6) {
      _submit(updated.join());
    }
  }

  void backspace() {
    if (state.digits.isEmpty) return;
    state = state.copyWith(
      digits: state.digits.sublist(0, state.digits.length - 1),
    );
  }

  Future<void> _submit(String pin) async {
    final repo = ref.read(pinRepositoryProvider);

    if (state.status == PinStatus.createPin) {
      state = state.copyWith(
        status: PinStatus.confirmPin,
        confirmBuffer: pin,
        digits: [],
      );
      return;
    }

    if (state.status == PinStatus.confirmPin) {
      if (pin == state.confirmBuffer) {
        await repo.savePin(pin);
        final nextStatus = state.biometricAvailable
            ? PinStatus.biometricSetup
            : PinStatus.unlocked;
        state = state.copyWith(
          status: nextStatus,
          digits: [],
          confirmBuffer: null,
        );
      } else {
        state = state.copyWith(
          status: PinStatus.createPin,
          digits: [],
          confirmBuffer: null,
          errorMessage: "PINs don't match. Try again.",
        );
      }
      return;
    }

    if (state.status == PinStatus.enterPin || state.status == PinStatus.error) {
      final correct = await repo.verifyPin(pin);
      if (correct) {
        state = state.copyWith(status: PinStatus.unlocked, digits: []);
      } else {
        state = state.copyWith(
          status: PinStatus.error,
          digits: [],
          errorMessage: 'Incorrect PIN. Try again.',
        );
      }
    }
  }

  Future<void> promptBiometrics() async {
    if (!state.biometricAvailable || !state.biometricEnabled) return;
    final authenticated = await ref
        .read(pinRepositoryProvider)
        .authenticateBiometric();
    if (authenticated) {
      state = state.copyWith(status: PinStatus.unlocked);
    }
  }

  Future<void> resetAll() async {
    await ref.read(pinRepositoryProvider).resetAll();
    state = const PinState(status: PinStatus.createPin);
  }

  Future<void> skipBiometricSetup() async {
    state = state.copyWith(status: PinStatus.unlocked);
  }

  Future<void> enableBiometric() async {
    await ref.read(pinRepositoryProvider).setBiometricEnabled(true);
    state = state.copyWith(status: PinStatus.unlocked, biometricEnabled: true);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await ref.read(pinRepositoryProvider).setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }
}
