import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontline/features/map/presentation/providers/map_provider.dart';

// ---------------------------------------------------------------------------
// Fake location service
// ---------------------------------------------------------------------------

class _FakeLocationService implements LocationService {
  final LatLng? _result;
  _FakeLocationService({LatLng? result}) : _result = result;

  @override
  Future<LatLng?> getCurrentLocation() async => _result;
}

ProviderContainer _container(LocationService svc) => ProviderContainer(
  overrides: [locationServiceProvider.overrideWithValue(svc)],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MapNotifier.locateMe — show', () {
    test('sets showUserMarker to true when location available', () async {
      final c = _container(_FakeLocationService(result: LatLng(50.0, 36.2)));
      addTearDown(c.dispose);
      await c.read(mapNotifierProvider.notifier).locateMe();
      expect(c.read(mapNotifierProvider).showUserMarker, isTrue);
    });

    test('sets userLocation to returned coordinates', () async {
      final c = _container(_FakeLocationService(result: LatLng(50.0, 36.2)));
      addTearDown(c.dispose);
      await c.read(mapNotifierProvider.notifier).locateMe();
      final loc = c.read(mapNotifierProvider).userLocation;
      expect(loc, isNotNull);
      expect(loc!.latitude, closeTo(50.0, 0.001));
      expect(loc.longitude, closeTo(36.2, 0.001));
    });

    test('locationCity is set when location available', () async {
      final c = _container(_FakeLocationService(result: LatLng(50.0, 36.2)));
      addTearDown(c.dispose);
      await c.read(mapNotifierProvider.notifier).locateMe();
      expect(c.read(mapNotifierProvider).locationCity, isNotNull);
      expect(c.read(mapNotifierProvider).locationCity, isNotEmpty);
    });
  });

  group('MapNotifier.locateMe — toggle off', () {
    test('sets showUserMarker to false on second call', () async {
      final c = _container(_FakeLocationService(result: LatLng(50.0, 36.2)));
      addTearDown(c.dispose);
      final n = c.read(mapNotifierProvider.notifier);
      await n.locateMe();
      await n.locateMe();
      expect(c.read(mapNotifierProvider).showUserMarker, isFalse);
    });

    test('clears userLocation on second call', () async {
      final c = _container(_FakeLocationService(result: LatLng(50.0, 36.2)));
      addTearDown(c.dispose);
      final n = c.read(mapNotifierProvider.notifier);
      await n.locateMe();
      await n.locateMe();
      expect(c.read(mapNotifierProvider).userLocation, isNull);
    });

    test('clears locationCity on second call', () async {
      final c = _container(_FakeLocationService(result: LatLng(50.0, 36.2)));
      addTearDown(c.dispose);
      final n = c.read(mapNotifierProvider.notifier);
      await n.locateMe();
      await n.locateMe();
      expect(c.read(mapNotifierProvider).locationCity, isNull);
    });
  });

  group('MapNotifier.locateMe — unavailable', () {
    test('does not set showUserMarker when location is null', () async {
      final c = _container(_FakeLocationService(result: null));
      addTearDown(c.dispose);
      await c.read(mapNotifierProvider.notifier).locateMe();
      expect(c.read(mapNotifierProvider).showUserMarker, isFalse);
    });

    test('leaves userLocation null when location unavailable', () async {
      final c = _container(_FakeLocationService(result: null));
      addTearDown(c.dispose);
      await c.read(mapNotifierProvider.notifier).locateMe();
      expect(c.read(mapNotifierProvider).userLocation, isNull);
    });
  });

  group('MapState — showUserMarker initial value', () {
    test('is false by default', () {
      expect(const MapState().showUserMarker, isFalse);
    });

    test('locationCity is null by default', () {
      expect(const MapState().locationCity, isNull);
    });
  });
}
