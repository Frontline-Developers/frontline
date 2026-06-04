import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/pin_state.dart';

abstract class PinDatasource {
  Future<PinStatus> getInitialStatus();
  Future<bool> verifyPin(String pin);
  Future<void> savePin(String pin);
  Future<void> resetAll();
  Future<bool> isBiometricAvailable();
  Future<bool> getBiometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> authenticateBiometric();
}

class PinDatasourceImpl implements PinDatasource {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  const PinDatasourceImpl({
    required FlutterSecureStorage storage,
    required LocalAuthentication localAuth,
  }) : _storage = storage,
       _localAuth = localAuth;

  @override
  Future<PinStatus> getInitialStatus() async {
    final setupComplete = await _storage.read(key: kAppSetupCompleteKey);
    final pinHash = await _storage.read(key: kPinHashStorageKey);

    if (setupComplete != null && pinHash == null) {
      return PinStatus.bypassWarning;
    }
    if (setupComplete == null) return PinStatus.createPin;
    return PinStatus.enterPin;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: kPinHashStorageKey);
    if (stored == null) return false;

    final salt = await _storage.read(key: kPinSaltStorageKey);
    if (salt != null) {
      // Salted path (current).
      return _hashPin(pin, salt) == stored;
    }

    // Legacy path — hash stored without a salt (migration).
    // If the PIN matches, re-save it with a salt before returning.
    if (_hashPin(pin, null) == stored) {
      await savePin(pin);
      return true;
    }
    return false;
  }

  @override
  Future<void> savePin(String pin) async {
    final salt = _generateSalt();
    await _storage.write(key: kPinSaltStorageKey, value: salt);
    await _storage.write(key: kPinHashStorageKey, value: _hashPin(pin, salt));
    await _storage.write(key: kAppSetupCompleteKey, value: 'true');
  }

  @override
  Future<void> resetAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> getBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBiometricEnabledKey) ?? false;
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBiometricEnabledKey, enabled);
  }

  @override
  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Frontline',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (_) {
      return false;
    }
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hashes [pin] with an optional [salt].
  /// Pass null for [salt] only when checking a legacy unsalted hash.
  String _hashPin(String pin, String? salt) {
    final input = salt != null ? '$salt:$pin' : pin;
    return sha256.convert(utf8.encode(input)).toString();
  }
}
