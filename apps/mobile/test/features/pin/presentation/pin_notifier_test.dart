import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/pin/domain/entities/pin_state.dart';
import 'package:frontline/features/pin/domain/repositories/pin_repository.dart';
import 'package:frontline/features/pin/presentation/providers/pin_provider.dart';

// ── Fake repository ────────────────────────────────────────────────────────────

class _FakeRepo implements PinRepository {
  PinStatus stubbedStatus;
  bool stubbedVerify;
  bool biometricAvailable;
  bool biometricEnabled;
  bool resetCalled = false;
  String? savedPin;
  bool? savedBiometricEnabled;
  bool throwOnGetStatus;

  _FakeRepo({
    this.stubbedStatus = PinStatus.createPin,
    this.stubbedVerify = false,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.throwOnGetStatus = false,
  });

  @override
  Future<PinStatus> getInitialStatus() async {
    if (throwOnGetStatus) throw StateError('simulated storage failure');
    return stubbedStatus;
  }

  @override
  Future<bool> verifyPin(String pin) async => stubbedVerify;

  @override
  Future<void> savePin(String pin) async {
    savedPin = pin;
  }

  @override
  Future<void> resetAll() async {
    resetCalled = true;
  }

  @override
  Future<bool> isBiometricAvailable() async => biometricAvailable;

  @override
  Future<bool> getBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    savedBiometricEnabled = enabled;
  }

  bool stubbedBiometricAuth = false;

  @override
  Future<bool> authenticateBiometric() async => stubbedBiometricAuth;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ProviderContainer _container(_FakeRepo repo) => ProviderContainer(
  overrides: [pinRepositoryProvider.overrideWithValue(repo)],
);

void _enterDigits(ProviderContainer c, List<int> digits) {
  for (final d in digits) {
    c.read(pinNotifierProvider.notifier).appendDigit(d);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('PinNotifier — initialization', () {
    test('initial state before async init is loading', () {
      final repo = _FakeRepo();
      final c = _container(repo);
      addTearDown(c.dispose);

      expect(c.read(pinNotifierProvider).status, PinStatus.loading);
    });

    test('transitions to createPin when no PIN is stored', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.createPin);
    });

    test('transitions to enterPin when PIN is stored', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.enterPin);
    });

    test(
      'transitions to bypassWarning when storage tampering detected',
      () async {
        final repo = _FakeRepo(stubbedStatus: PinStatus.bypassWarning);
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(pinNotifierProvider);
        await Future.delayed(Duration.zero);

        expect(c.read(pinNotifierProvider).status, PinStatus.bypassWarning);
      },
    );

    test('sets biometricAvailable from repository', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.enterPin,
        biometricAvailable: true,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).biometricAvailable, isTrue);
    });

    test('sets biometricEnabled from repository', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.enterPin,
        biometricAvailable: true,
        biometricEnabled: true,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).biometricEnabled, isTrue);
    });
  });

  group('PinNotifier — digit input', () {
    test('appendDigit adds digit to list', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      c.read(pinNotifierProvider.notifier).appendDigit(5);

      expect(c.read(pinNotifierProvider).digits, [5]);
    });

    test('appendDigit accumulates multiple digits in order', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3]);

      expect(c.read(pinNotifierProvider).digits, [1, 2, 3]);
    });

    test('backspace removes last digit', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2]);
      c.read(pinNotifierProvider.notifier).backspace();

      expect(c.read(pinNotifierProvider).digits, [1]);
    });

    test('backspace on empty digits is a no-op', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      c.read(pinNotifierProvider.notifier).backspace();

      expect(c.read(pinNotifierProvider).digits, isEmpty);
    });
  });

  group('PinNotifier — createPin flow', () {
    test('6 digits in createPin transitions to confirmPin', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.confirmPin);
    });

    test('confirmBuffer is set after first 6 digits in createPin', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).confirmBuffer, isNotNull);
    });

    test('digits are cleared when entering confirmPin step', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).digits, isEmpty);
    });

    test('matching confirmPin digits → status is unlocked', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]); // create
      await Future.delayed(Duration.zero);
      _enterDigits(c, [1, 2, 3, 4, 5, 6]); // confirm same
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.unlocked);
    });

    test('matching confirmPin → savePin is called on repository', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);
      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(repo.savedPin, isNotNull);
    });

    test('mismatched confirmPin → back to createPin', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);
      _enterDigits(c, [6, 5, 4, 3, 2, 1]); // different
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.createPin);
    });

    test('mismatched confirmPin → errorMessage is set', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);
      _enterDigits(c, [6, 5, 4, 3, 2, 1]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).errorMessage, isNotNull);
    });

    test('mismatched confirmPin → confirmBuffer is cleared', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.createPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);
      _enterDigits(c, [6, 5, 4, 3, 2, 1]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).confirmBuffer, isNull);
    });
  });

  group('PinNotifier — enterPin flow', () {
    test('correct PIN → status is unlocked', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.enterPin,
        stubbedVerify: true,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.unlocked);
    });

    test('wrong PIN → status is error', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.enterPin,
        stubbedVerify: false,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.error);
    });

    test('wrong PIN → errorMessage is set', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.enterPin,
        stubbedVerify: false,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).errorMessage, isNotNull);
    });

    test('wrong PIN → digits are cleared', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.enterPin,
        stubbedVerify: false,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).digits, isEmpty);
    });
  });

  group('PinNotifier — resetAll', () {
    test('calls repository resetAll', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      await c.read(pinNotifierProvider.notifier).resetAll();

      expect(repo.resetCalled, isTrue);
    });

    test('transitions to createPin after reset', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      await c.read(pinNotifierProvider.notifier).resetAll();

      expect(c.read(pinNotifierProvider).status, PinStatus.createPin);
    });

    test('digits are empty after reset', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      c.read(pinNotifierProvider.notifier).appendDigit(1);
      await c.read(pinNotifierProvider.notifier).resetAll();

      expect(c.read(pinNotifierProvider).digits, isEmpty);
    });

    test('errorMessage and confirmBuffer are cleared after reset', () async {
      final repo = _FakeRepo(stubbedStatus: PinStatus.enterPin);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      await c.read(pinNotifierProvider.notifier).resetAll();

      final s = c.read(pinNotifierProvider);
      expect(s.errorMessage, isNull);
      expect(s.confirmBuffer, isNull);
    });
  });

  group('PinNotifier — biometric setup after PIN creation', () {
    test(
      'matching confirmPin with biometrics available → biometricSetup',
      () async {
        final repo = _FakeRepo(
          stubbedStatus: PinStatus.createPin,
          biometricAvailable: true,
        );
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(pinNotifierProvider);
        await Future.delayed(Duration.zero);

        _enterDigits(c, [1, 2, 3, 4, 5, 6]);
        await Future.delayed(Duration.zero);
        _enterDigits(c, [1, 2, 3, 4, 5, 6]);
        await Future.delayed(Duration.zero);

        expect(c.read(pinNotifierProvider).status, PinStatus.biometricSetup);
      },
    );

    test(
      'matching confirmPin without biometrics → directly unlocked',
      () async {
        final repo = _FakeRepo(
          stubbedStatus: PinStatus.createPin,
          biometricAvailable: false,
        );
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(pinNotifierProvider);
        await Future.delayed(Duration.zero);

        _enterDigits(c, [1, 2, 3, 4, 5, 6]);
        await Future.delayed(Duration.zero);
        _enterDigits(c, [1, 2, 3, 4, 5, 6]);
        await Future.delayed(Duration.zero);

        expect(c.read(pinNotifierProvider).status, PinStatus.unlocked);
      },
    );

    test('skipBiometricSetup → status becomes unlocked', () async {
      final repo = _FakeRepo(
        stubbedStatus: PinStatus.createPin,
        biometricAvailable: true,
      );
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);
      _enterDigits(c, [1, 2, 3, 4, 5, 6]);
      await Future.delayed(Duration.zero);

      await c.read(pinNotifierProvider.notifier).skipBiometricSetup();

      expect(c.read(pinNotifierProvider).status, PinStatus.unlocked);
    });

    test(
      'enableBiometric → setBiometricEnabled called and status unlocked',
      () async {
        final repo = _FakeRepo(
          stubbedStatus: PinStatus.createPin,
          biometricAvailable: true,
        );
        final c = _container(repo);
        addTearDown(c.dispose);

        c.read(pinNotifierProvider);
        await Future.delayed(Duration.zero);

        _enterDigits(c, [1, 2, 3, 4, 5, 6]);
        await Future.delayed(Duration.zero);
        _enterDigits(c, [1, 2, 3, 4, 5, 6]);
        await Future.delayed(Duration.zero);

        await c.read(pinNotifierProvider.notifier).enableBiometric();

        expect(repo.savedBiometricEnabled, isTrue);
        expect(c.read(pinNotifierProvider).status, PinStatus.unlocked);
      },
    );
  });

  group('PinNotifier — storage failure recovery', () {
    test('falls back to createPin when storage read throws', () async {
      final repo = _FakeRepo(throwOnGetStatus: true);
      final c = _container(repo);
      addTearDown(c.dispose);

      c.read(pinNotifierProvider);
      await Future.delayed(Duration.zero);

      expect(c.read(pinNotifierProvider).status, PinStatus.createPin);
    });
  });
}
