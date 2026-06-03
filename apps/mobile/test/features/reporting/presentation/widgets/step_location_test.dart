import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';
import 'package:frontline/features/reporting/presentation/providers/reporting_provider.dart';
import 'package:frontline/features/reporting/presentation/widgets/step_location.dart';
import 'package:latlong2/latlong.dart';

/// Per CLAUDE.md #11 — extend the real Notifier, no mocks.
class _FakeReportingNotifier extends ReportingNotifier {
  final ReportingState seed;
  _FakeReportingNotifier({this.seed = const ReportingState()});

  @override
  ReportingState build() => seed;
}

Widget _harness({ReportDraft draft = const ReportDraft()}) {
  return ProviderScope(
    overrides: [
      reportingNotifierProvider.overrideWith(
        () => _FakeReportingNotifier(seed: ReportingState(draft: draft)),
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

void main() {
  group('StepLocation (flutter_map picker)', () {
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
}
