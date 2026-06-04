import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/alerts/presentation/providers/alert_provider.dart';

void main() {
  group('AlertNotifier', () {
    test('initial state is idle', () {
      final container = ProviderContainer(
        overrides: [
          alertNotifierProvider.overrideWith(() => _FakeAlertNotifier()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(alertNotifierProvider).status, AlertStatus.idle);
    });

    test('state is saved after successful save', () async {
      final fake = _FakeAlertNotifier();
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-1',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );

      expect(container.read(alertNotifierProvider).status, AlertStatus.saved);
    });

    test('state is error when save throws', () async {
      final fake = _FakeAlertNotifier(shouldThrow: true);
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-1',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );

      final state = container.read(alertNotifierProvider);
      expect(state.status, AlertStatus.error);
      expect(state.error, isNotNull);
    });

    test('error is null in initial state', () {
      final container = ProviderContainer(
        overrides: [
          alertNotifierProvider.overrideWith(() => _FakeAlertNotifier()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(alertNotifierProvider).error, isNull);
    });

    test('save increments saveCallCount', () async {
      final fake = _FakeAlertNotifier();
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-1',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );

      expect(fake.saveCallCount, 1);
    });
  });

  group('AlertNotifier.reset', () {
    test('returns status to idle after saved', () async {
      final fake = _FakeAlertNotifier();
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-1',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );
      expect(container.read(alertNotifierProvider).status, AlertStatus.saved);

      container.read(alertNotifierProvider.notifier).reset();
      expect(container.read(alertNotifierProvider).status, AlertStatus.idle);
    });

    test('clears error after error state', () async {
      final fake = _FakeAlertNotifier(shouldThrow: true);
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-1',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );
      expect(container.read(alertNotifierProvider).status, AlertStatus.error);

      container.read(alertNotifierProvider.notifier).reset();
      expect(container.read(alertNotifierProvider).status, AlertStatus.idle);
      expect(container.read(alertNotifierProvider).error, isNull);
    });
  });

  group('AlertNotifier — saving intermediate state', () {
    test('status is saving while async save is in progress', () async {
      final fake = _DelayedAlertNotifier();
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      final saveFuture = container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-1',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );

      // Status is saving synchronously before the completer resolves.
      expect(container.read(alertNotifierProvider).status, AlertStatus.saving);

      fake.completer.complete();
      await saveFuture;
      expect(container.read(alertNotifierProvider).status, AlertStatus.saved);
    });
  });
}

class _FakeAlertNotifier extends AlertNotifier {
  final bool shouldThrow;
  int saveCallCount = 0;

  _FakeAlertNotifier({this.shouldThrow = false});

  @override
  AlertState build() => const AlertState();

  @override
  Future<void> save({
    required String userId,
    required String locationLabel,
    required double lat,
    required double lng,
    required double radiusKm,
    required List<String> categories,
  }) async {
    saveCallCount++;
    if (shouldThrow) {
      state = state.copyWith(status: AlertStatus.error, error: 'Save failed');
      return;
    }
    state = state.copyWith(status: AlertStatus.saved, error: null);
  }
}

class _DelayedAlertNotifier extends AlertNotifier {
  final Completer<void> completer = Completer<void>();

  @override
  AlertState build() => const AlertState();

  @override
  Future<void> save({
    required String userId,
    required String locationLabel,
    required double lat,
    required double lng,
    required double radiusKm,
    required List<String> categories,
  }) async {
    state = state.copyWith(status: AlertStatus.saving, error: null);
    await completer.future;
    state = state.copyWith(status: AlertStatus.saved, error: null);
  }
}
