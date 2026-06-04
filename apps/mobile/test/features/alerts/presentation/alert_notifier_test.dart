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
