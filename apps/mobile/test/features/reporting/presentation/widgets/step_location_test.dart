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
      'moving the map controller commits the new center as draft lat/lng',
      (tester) async {
        await _sizedSurface(tester);
        await tester.pumpWidget(_harness());
        await tester.pump(const Duration(milliseconds: 50));

        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        // Programmatic move to Kharkiv. Must trigger the draft update —
        // we don't gate on hasGesture so "use my location" also commits.
        flutterMap.mapController!.move(const LatLng(49.9935, 36.2304), 12);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(StepLocation)),
        );
        final draft = container.read(reportingNotifierProvider).draft;
        expect(draft.lat, closeTo(49.9935, 1e-4));
        expect(draft.lng, closeTo(36.2304, 1e-4));
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
