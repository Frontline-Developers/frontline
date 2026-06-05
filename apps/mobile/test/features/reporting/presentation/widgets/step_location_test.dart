import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';
import 'package:frontline/features/reporting/presentation/providers/reporting_provider.dart';
import 'package:frontline/features/reporting/presentation/widgets/step_location.dart';
import 'package:latlong2/latlong.dart';

// ── Fake notifier (CLAUDE.md #11 — extend real Notifier, no mock frameworks) ─

class _FakeReportingNotifier extends ReportingNotifier {
  final ReportingState seed;
  _FakeReportingNotifier({this.seed = const ReportingState()});

  @override
  ReportingState build() => seed;
}

// ── Fake geocoding services ───────────────────────────────────────────────────

class _FakeGeocodingService implements GeocodingService {
  String? reverseResult = 'Test City, Test Country';
  ({double lat, double lng})? forwardResult;
  int reverseCallCount = 0;
  int forwardCallCount = 0;

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    reverseCallCount++;
    return reverseResult;
  }

  @override
  Future<({double lat, double lng})?> forwardGeocode(String address) async {
    forwardCallCount++;
    return forwardResult;
  }
}

class _SlowGeocodingService implements GeocodingService {
  final Future<({double lat, double lng})?> forwardFuture;
  _SlowGeocodingService({required this.forwardFuture});

  @override
  Future<String?> reverseGeocode(double lat, double lng) async => null;

  @override
  Future<({double lat, double lng})?> forwardGeocode(String address) =>
      forwardFuture;
}

// ── Test harness ──────────────────────────────────────────────────────────────

Widget _harness({
  ReportDraft draft = const ReportDraft(),
  GeocodingService? geocodingSvc,
}) {
  return ProviderScope(
    overrides: [
      reportingNotifierProvider.overrideWith(
        () => _FakeReportingNotifier(seed: ReportingState(draft: draft)),
      ),
      geocodingServiceProvider.overrideWithValue(
        geocodingSvc ?? _FakeGeocodingService(),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: EdgeInsets.all(16), child: StepLocation()),
        ),
      ),
    ),
  );
}

Future<void> _sizedSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Builds a synthetic [MapCamera] for use in [MapOptions.onPositionChanged]
/// tests. [nonRotatedSize] matches the map widget's 220px height slot inside
/// the 420px-wide test surface.
MapCamera _camera(LatLng center, {double zoom = 12}) => MapCamera(
  crs: const Epsg3857(),
  center: center,
  zoom: zoom,
  rotation: 0,
  nonRotatedSize: const Size(420, 220),
);

void main() {
  group('StepLocation (flutter_map picker) — existing behaviour', () {
    testWidgets('renders an interactive FlutterMap widget', (tester) async {
      await _sizedSurface(tester);
      await tester.pumpWidget(_harness());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('renders the fixed center crosshair overlay', (tester) async {
      await _sizedSurface(tester);
      await tester.pumpWidget(_harness());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('locationCrosshair')), findsOneWidget);
    });

    testWidgets(
      'programmatic map move does not commit draft coords (gesture-only)',
      (tester) async {
        await _sizedSurface(tester);
        await tester.pumpWidget(_harness());
        await tester.pump(const Duration(milliseconds: 50));

        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        // Only user gestures commit lat/lng; programmatic moves (e.g. from
        // _useMyLocation) write coords directly via updateDraft, not via the
        // onPositionChanged callback.
        flutterMap.mapController!.move(const LatLng(49.9935, 36.2304), 12);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(StepLocation)),
        );
        final draft = container.read(reportingNotifierProvider).draft;
        expect(draft.lat, isNull);
        expect(draft.lng, isNull);
      },
    );

    testWidgets(
      'pre-set draft lat/lng is used as initial map center (back-nav restore)',
      (tester) async {
        await _sizedSurface(tester);

        const kyiv = ReportDraft(lat: 50.45, lng: 30.52);
        await tester.pumpWidget(_harness(draft: kyiv));
        await tester.pump(const Duration(milliseconds: 50));

        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(flutterMap.options.initialCenter.latitude, closeTo(50.45, 1e-4));
        expect(
          flutterMap.options.initialCenter.longitude,
          closeTo(30.52, 1e-4),
        );
      },
    );
  });

  // ── Forward geocoding (text → map) ──────────────────────────────────────────

  group('StepLocation — forward geocoding (text → map)', () {
    testWidgets('search button is rendered in TextField suffix', (
      tester,
    ) async {
      await _sizedSurface(tester);
      await tester.pumpWidget(_harness());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('locationSearchButton')), findsOneWidget);
    });

    testWidgets(
      'tapping search button with non-empty text calls forwardGeocode',
      (tester) async {
        await _sizedSurface(tester);
        final svc = _FakeGeocodingService()
          ..forwardResult = (lat: 50.45, lng: 30.52);
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.enterText(find.byType(TextField), 'Kyiv');
        await tester.pump();
        await tester.tap(find.byKey(const Key('locationSearchButton')));
        await tester.pumpAndSettle();

        expect(svc.forwardCallCount, 1);
      },
    );

    testWidgets(
      'forward geocode success updates draft lat/lng and structured label',
      (tester) async {
        await _sizedSurface(tester);
        final svc = _FakeGeocodingService()
          ..forwardResult = (lat: 50.45, lng: 30.52)
          ..reverseResult = 'Kyiv, Kyiv City, Ukraine';
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.enterText(find.byType(TextField), 'Kyiv');
        await tester.pump();
        await tester.tap(find.byKey(const Key('locationSearchButton')));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(StepLocation)),
        );
        final draft = container.read(reportingNotifierProvider).draft;
        expect(draft.lat, closeTo(50.45, 1e-4));
        expect(draft.lng, closeTo(30.52, 1e-4));
        expect(draft.locationLabel, 'Kyiv, Kyiv City, Ukraine');
        expect(
          find.widgetWithText(TextField, 'Kyiv, Kyiv City, Ukraine'),
          findsOneWidget,
        );
      },
    );

    testWidgets('forward geocode null result shows snackbar', (tester) async {
      await _sizedSurface(tester);
      final svc = _FakeGeocodingService()..forwardResult = null;
      await tester.pumpWidget(_harness(geocodingSvc: svc));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), 'xyzzy_not_a_place');
      await tester.pump();
      await tester.tap(find.byKey(const Key('locationSearchButton')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'pressing Enter (TextInputAction.search) triggers forwardGeocode',
      (tester) async {
        await _sizedSurface(tester);
        final svc = _FakeGeocodingService()
          ..forwardResult = (lat: 48.85, lng: 2.35);
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.enterText(find.byType(TextField), 'Paris');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(svc.forwardCallCount, 1);
      },
    );
  });

  // ── Reverse geocoding (map → text) ──────────────────────────────────────────

  group('StepLocation — reverse geocoding (map → text)', () {
    testWidgets(
      'map gesture fires reverseGeocode after 800ms debounce and updates label',
      (tester) async {
        await _sizedSurface(tester);
        final svc = _FakeGeocodingService()..reverseResult = 'Kyiv, Ukraine';
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        // Simulate a user gesture via the callback (hasGesture = true).
        map.options.onPositionChanged!(
          _camera(const LatLng(50.45, 30.52)),
          true,
        );

        // Before 800ms the debounce hasn't fired.
        await tester.pump(const Duration(milliseconds: 400));
        expect(svc.reverseCallCount, 0);

        // After the debounce fires.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(svc.reverseCallCount, 1);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(StepLocation)),
        );
        final draft = container.read(reportingNotifierProvider).draft;
        expect(draft.locationLabel, 'Kyiv, Ukraine');
      },
    );

    testWidgets(
      'multiple gestures within 800ms debounce window result in exactly one call',
      (tester) async {
        await _sizedSurface(tester);
        final svc = _FakeGeocodingService()..reverseResult = 'Kharkiv, Ukraine';
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final cb = map.options.onPositionChanged!;

        // Three rapid gestures within the 800ms window.
        cb(_camera(const LatLng(50.0, 36.0)), true);
        await tester.pump(const Duration(milliseconds: 200));
        cb(_camera(const LatLng(50.1, 36.1)), true);
        await tester.pump(const Duration(milliseconds: 200));
        cb(_camera(const LatLng(50.2, 36.2)), true);

        // Let the final debounce complete.
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(svc.reverseCallCount, 1);
      },
    );

    testWidgets(
      'programmatic map move (hasGesture=false) does NOT trigger reverseGeocode',
      (tester) async {
        await _sizedSurface(tester);
        final svc = _FakeGeocodingService()..reverseResult = 'Odessa, Ukraine';
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        // hasGesture = false  →  no reverse geocode should fire.
        map.options.onPositionChanged!(
          _camera(const LatLng(46.48, 30.72)),
          false,
        );
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(svc.reverseCallCount, 0);
      },
    );

    testWidgets('null reverseGeocode result leaves label unchanged', (
      tester,
    ) async {
      await _sizedSurface(tester);
      const existingLabel = 'Manually entered';
      final svc = _FakeGeocodingService()..reverseResult = null;
      await tester.pumpWidget(
        _harness(
          draft: const ReportDraft(locationLabel: existingLabel),
          geocodingSvc: svc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.options.onPositionChanged!(_camera(const LatLng(50.0, 36.0)), true);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, existingLabel), findsOneWidget);
    });
  });

  // ── Loading indicator ────────────────────────────────────────────────────────

  group('StepLocation — geocoding loading indicator', () {
    testWidgets(
      'loading spinner replaces search icon while geocoding is in progress',
      (tester) async {
        await _sizedSurface(tester);
        final completer = Completer<({double lat, double lng})?>();
        final svc = _SlowGeocodingService(forwardFuture: completer.future);
        await tester.pumpWidget(_harness(geocodingSvc: svc));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.enterText(find.byType(TextField), 'Kyiv');
        await tester.pump();

        await tester.tap(find.byKey(const Key('locationSearchButton')));
        // One frame to start the async operation — spinner should be visible.
        await tester.pump();

        expect(find.byKey(const Key('locationSearchButton')), findsNothing);

        // Resolve the future and confirm the search button is restored.
        completer.complete(null);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('locationSearchButton')), findsOneWidget);
      },
    );
  });
}
