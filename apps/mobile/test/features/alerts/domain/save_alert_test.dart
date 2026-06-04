import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/alerts/domain/entities/alert_subscription.dart';
import 'package:frontline/features/alerts/domain/repositories/alert_repository.dart';
import 'package:frontline/features/alerts/domain/usecases/save_alert.dart';

void main() {
  late _FakeAlertRepository repo;
  late SaveAlert useCase;

  setUp(() {
    repo = _FakeAlertRepository();
    useCase = SaveAlert(repo);
  });

  group('SaveAlert', () {
    test('returns id from repository on success', () async {
      repo.stubbedId = 'sub-abc';
      final id = await useCase(
        userId: 'uid-1',
        locationLabel: 'Kyiv',
        lat: 50.45,
        lng: 30.52,
        radiusKm: 5,
        categories: ['combat', 'alert'],
      );
      expect(id, 'sub-abc');
    });

    test('passes correct subscription data to repository', () async {
      await useCase(
        userId: 'uid-1',
        locationLabel: 'Kyiv',
        lat: 50.45,
        lng: 30.52,
        radiusKm: 5,
        categories: ['combat', 'alert'],
      );
      final saved = repo.lastSaved!;
      expect(saved.userId, 'uid-1');
      expect(saved.locationLabel, 'Kyiv');
      expect(saved.lat, 50.45);
      expect(saved.lng, 30.52);
      expect(saved.radiusKm, 5);
      expect(saved.categories, ['combat', 'alert']);
    });

    test('throws ArgumentError when categories is empty', () {
      expect(
        () => useCase(
          userId: 'uid-1',
          locationLabel: 'Kyiv',
          lat: 50.45,
          lng: 30.52,
          radiusKm: 5,
          categories: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when radiusKm is below 1', () {
      expect(
        () => useCase(
          userId: 'uid-1',
          locationLabel: 'Kyiv',
          lat: 50.45,
          lng: 30.52,
          radiusKm: 0,
          categories: ['combat'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when radiusKm exceeds 20', () {
      expect(
        () => useCase(
          userId: 'uid-1',
          locationLabel: 'Kyiv',
          lat: 50.45,
          lng: 30.52,
          radiusKm: 21,
          categories: ['combat'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('does not call repository when validation fails', () async {
      try {
        await useCase(
          userId: 'uid-1',
          locationLabel: 'Kyiv',
          lat: 50.45,
          lng: 30.52,
          radiusKm: 5,
          categories: [],
        );
      } catch (_) {}
      expect(repo.saveCallCount, 0);
    });

    test('subscription has createdAt set', () async {
      final before = DateTime.now();
      await useCase(
        userId: 'uid-1',
        locationLabel: 'Kyiv',
        lat: 50.45,
        lng: 30.52,
        radiusKm: 5,
        categories: ['combat'],
      );
      final after = DateTime.now();
      final saved = repo.lastSaved!;
      expect(
        saved.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        saved.createdAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('succeeds with radiusKm at minimum boundary (1)', () async {
      final id = await useCase(
        userId: 'uid-1',
        locationLabel: 'Kyiv',
        lat: 50.45,
        lng: 30.52,
        radiusKm: 1,
        categories: ['combat'],
      );
      expect(id, isNotNull);
      expect(repo.saveCallCount, 1);
    });

    test('succeeds with radiusKm at maximum boundary (20)', () async {
      final id = await useCase(
        userId: 'uid-1',
        locationLabel: 'Kyiv',
        lat: 50.45,
        lng: 30.52,
        radiusKm: 20,
        categories: ['combat'],
      );
      expect(id, isNotNull);
      expect(repo.saveCallCount, 1);
    });
  });
}

class _FakeAlertRepository implements AlertRepository {
  String stubbedId = 'fake-id';
  AlertSubscription? lastSaved;
  int saveCallCount = 0;
  Exception? stubbedError;

  @override
  Future<String> save(AlertSubscription subscription) async {
    if (stubbedError != null) throw stubbedError!;
    saveCallCount++;
    lastSaved = subscription;
    return stubbedId;
  }
}
