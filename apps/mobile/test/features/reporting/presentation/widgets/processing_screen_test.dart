import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/presentation/widgets/processing_screen.dart';

Widget _harness(int step) => MaterialApp(
  home: Scaffold(body: ProcessingScreen(step: step)),
);

void main() {
  group('ProcessingScreen', () {
    testWidgets('renders all 4 checklist row labels', (tester) async {
      await tester.pumpWidget(_harness(0));
      expect(find.text('Stripping EXIF metadata'), findsOneWidget);
      expect(find.text('Randomizing GPS coordinates ±3km'), findsOneWidget);
      expect(find.text('Not logging IP address'), findsOneWidget);
      expect(find.text('Generating anonymous token'), findsOneWidget);
    });

    testWidgets('step=0: no rows are done (no check icons visible)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(0));
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('step=4: all 4 rows are done (check icons visible)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(4));
      expect(find.byIcon(Icons.check), findsNWidgets(4));
    });
  });
}
