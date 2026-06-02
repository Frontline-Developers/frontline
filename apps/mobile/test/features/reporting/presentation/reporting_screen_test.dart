import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';
import 'package:frontline/features/reporting/domain/repositories/reporting_repository.dart';
import 'package:frontline/features/reporting/presentation/providers/reporting_provider.dart';
import 'package:frontline/features/reporting/presentation/screens/reporting_screen.dart';

class _FakeRepo implements ReportingRepository {
  int submitCount = 0;
  @override
  Future<SubmitResult> submitReport(
    ReportDraft draft, {
    SubmitProgressCallback? onProgress,
  }) async {
    submitCount++;
    return const SubmitResult(
      reportId: 'r1',
      displayToken: 'abcd-1234-efgh-5678',
    );
  }
}

Widget _harness(_FakeRepo repo) => ProviderScope(
  overrides: [reportingRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: ReportingScreen()),
);

Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('renders Step 1 by default with step indicator', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness(_FakeRepo()));
    expect(find.text('What did you see?'), findsOneWidget);
    expect(find.text('Step 1 of 3 · no account, no tracking'), findsOneWidget);
  });

  testWidgets('Continue is disabled until describe is valid', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness(_FakeRepo()));
    final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
    expect(tester.widget<ElevatedButton>(continueBtn).onPressed, isNull);
  });

  testWidgets('Continue enables and advances when describe is valid', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness(_FakeRepo()));
    await tester.enterText(
      find.byType(TextField).first,
      'a drone hit the substation',
    );
    await tester.tap(find.text('Combat / strike'));
    await tester.pumpAndSettle();
    final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
    expect(tester.widget<ElevatedButton>(continueBtn).onPressed, isNotNull);
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();
    expect(find.text('Where, roughly?'), findsOneWidget);
  });

  testWidgets('Back returns to previous step', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness(_FakeRepo()));
    await tester.enterText(
      find.byType(TextField).first,
      'a drone hit the substation',
    );
    await tester.tap(find.text('Combat / strike'));
    await tester.pumpAndSettle();
    final cont = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.ensureVisible(cont);
    await tester.tap(cont);
    await tester.pumpAndSettle();
    final back = find.widgetWithText(OutlinedButton, 'Back');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('What did you see?'), findsOneWidget);
  });
}
