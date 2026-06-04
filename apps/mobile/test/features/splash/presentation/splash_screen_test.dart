import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/splash/presentation/screens/splash_screen.dart';

Widget _wrap() => const MaterialApp(home: SplashScreen());

void main() {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Frontline'), findsOneWidget);
  });

  testWidgets('shows subtitle', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(
      find.text('Reports from the people on the frontline'),
      findsOneWidget,
    );
  });

  testWidgets('shows privacy note', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(
      find.text('No account · No tracking · IP never stored'),
      findsOneWidget,
    );
  });

  testWidgets('shows linear progress indicator', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows loading label', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Loading live reports...'), findsOneWidget);
  });
}
