import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/pin/domain/entities/pin_state.dart';

void main() {
  group('PinStatus', () {
    test('has all expected values', () {
      expect(
        PinStatus.values,
        containsAll([
          PinStatus.loading,
          PinStatus.createPin,
          PinStatus.confirmPin,
          PinStatus.enterPin,
          PinStatus.bypassWarning,
          PinStatus.biometricSetup,
          PinStatus.unlocked,
          PinStatus.error,
        ]),
      );
    });
  });

  group('PinState — defaults', () {
    test('default status is loading', () {
      const s = PinState();
      expect(s.status, PinStatus.loading);
    });

    test('default digits is empty', () {
      const s = PinState();
      expect(s.digits, isEmpty);
    });

    test('default nullable fields are null', () {
      const s = PinState();
      expect(s.confirmBuffer, isNull);
      expect(s.errorMessage, isNull);
    });

    test('default booleans are false', () {
      const s = PinState();
      expect(s.biometricAvailable, isFalse);
      expect(s.biometricEnabled, isFalse);
    });
  });

  group('PinState — copyWith non-nullable fields', () {
    test('copyWith updates status', () {
      const s = PinState();
      final updated = s.copyWith(status: PinStatus.createPin);
      expect(updated.status, PinStatus.createPin);
    });

    test('copyWith updates digits', () {
      const s = PinState();
      final updated = s.copyWith(digits: [1, 2, 3]);
      expect(updated.digits, [1, 2, 3]);
    });

    test('copyWith updates biometricAvailable', () {
      const s = PinState();
      final updated = s.copyWith(biometricAvailable: true);
      expect(updated.biometricAvailable, isTrue);
    });

    test('copyWith updates biometricEnabled', () {
      const s = PinState();
      final updated = s.copyWith(biometricEnabled: true);
      expect(updated.biometricEnabled, isTrue);
    });

    test('copyWith without args preserves all fields', () {
      final s = PinState(
        status: PinStatus.enterPin,
        digits: [1, 2],
        biometricAvailable: true,
        biometricEnabled: true,
      );
      final updated = s.copyWith();
      expect(updated.status, PinStatus.enterPin);
      expect(updated.digits, [1, 2]);
      expect(updated.biometricAvailable, isTrue);
      expect(updated.biometricEnabled, isTrue);
    });
  });

  group('PinState — copyWith sentinel for errorMessage', () {
    test('preserves errorMessage when not passed to copyWith', () {
      final s = PinState(status: PinStatus.error, errorMessage: 'Wrong PIN');
      final updated = s.copyWith(status: PinStatus.enterPin);
      expect(updated.errorMessage, 'Wrong PIN');
    });

    test('clears errorMessage with explicit null', () {
      final s = PinState(status: PinStatus.error, errorMessage: 'Wrong PIN');
      final updated = s.copyWith(errorMessage: null);
      expect(updated.errorMessage, isNull);
    });

    test('sets errorMessage via copyWith', () {
      const s = PinState();
      final updated = s.copyWith(errorMessage: 'PINs do not match');
      expect(updated.errorMessage, 'PINs do not match');
    });
  });

  group('PinState — copyWith sentinel for confirmBuffer', () {
    test('preserves confirmBuffer when not passed to copyWith', () {
      final s = PinState(status: PinStatus.confirmPin, confirmBuffer: '123456');
      final updated = s.copyWith(status: PinStatus.confirmPin);
      expect(updated.confirmBuffer, '123456');
    });

    test('clears confirmBuffer with explicit null', () {
      final s = PinState(status: PinStatus.confirmPin, confirmBuffer: '123456');
      final updated = s.copyWith(confirmBuffer: null);
      expect(updated.confirmBuffer, isNull);
    });

    test('sets confirmBuffer via copyWith', () {
      const s = PinState();
      final updated = s.copyWith(confirmBuffer: '654321');
      expect(updated.confirmBuffer, '654321');
    });
  });
}
