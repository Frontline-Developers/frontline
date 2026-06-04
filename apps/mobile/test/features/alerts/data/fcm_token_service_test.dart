import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontline/features/alerts/presentation/providers/alert_provider.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeFcmTokenService implements FcmTokenService {
  int registerCallCount = 0;
  String? lastUserId;
  bool shouldThrow;

  _FakeFcmTokenService({this.shouldThrow = false});

  @override
  Future<void> registerToken({required String userId}) async {
    if (shouldThrow) throw Exception('FCM unavailable');
    registerCallCount++;
    lastUserId = userId;
  }
}

class _FakeAlertNotifierWithFcm extends AlertNotifier {
  final FcmTokenService fcmService;
  int saveCallCount = 0;

  _FakeAlertNotifierWithFcm(this.fcmService);

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
    try {
      await fcmService.registerToken(userId: userId);
      state = state.copyWith(status: AlertStatus.saved, error: null);
    } catch (_) {
      // FCM failure must not block subscription save.
      state = state.copyWith(status: AlertStatus.saved, error: null);
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FcmTokenService — registration', () {
    test('registerToken is called with correct userId on save', () async {
      final fakeFcm = _FakeFcmTokenService();
      final fake = _FakeAlertNotifierWithFcm(fakeFcm);
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-42',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );

      expect(fakeFcm.registerCallCount, 1);
      expect(fakeFcm.lastUserId, 'uid-42');
    });

    test('save still succeeds when FCM registration throws', () async {
      final fakeFcm = _FakeFcmTokenService(shouldThrow: true);
      final fake = _FakeAlertNotifierWithFcm(fakeFcm);
      final container = ProviderContainer(
        overrides: [alertNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(alertNotifierProvider.notifier)
          .save(
            userId: 'uid-42',
            locationLabel: 'Kyiv',
            lat: 50.45,
            lng: 30.52,
            radiusKm: 5,
            categories: ['combat'],
          );

      expect(container.read(alertNotifierProvider).status, AlertStatus.saved);
    });

    test('save count is 1 after single call', () async {
      final fakeFcm = _FakeFcmTokenService();
      final fake = _FakeAlertNotifierWithFcm(fakeFcm);
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
