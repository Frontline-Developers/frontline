import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/compare/presentation/providers/compare_provider.dart';
import 'package:frontline/features/compare/presentation/screens/compare_screen.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:go_router/go_router.dart';

final _report = NewsItem(
  id: 'r1',
  title: 'Strike near Kyiv',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 1, 1),
  category: 'combat',
  status: ItemStatus.pending,
);

class _FakeCompareNotifier extends CompareNotifier {
  final CompareState _initial;
  _FakeCompareNotifier(this._initial);

  @override
  CompareState build() => _initial;

  @override
  Future<void> load(String reportId) async {}
}

Widget _harness({String? reportId, required CompareState state}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => CompareScreen(reportId: reportId),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      compareNotifierProvider.overrideWith(() => _FakeCompareNotifier(state)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders no-report hint when reportId is null', (tester) async {
    await tester.pumpWidget(
      _harness(reportId: null, state: const CompareState()),
    );
    expect(find.text('Compare Coverage'), findsOneWidget);
    expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
  });

  testWidgets('shows loading indicator while state is loading', (tester) async {
    await tester.pumpWidget(
      _harness(reportId: 'r1', state: const CompareState(isLoading: true)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error message when state has error', (tester) async {
    await tester.pumpWidget(
      _harness(
        reportId: 'r1',
        state: const CompareState(
          error: 'Could not load compare data. Please try again.',
        ),
      ),
    );
    expect(
      find.text('Could not load compare data. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows hero card and view toggle when report is loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        reportId: 'r1',
        state: CompareState(report: _report, wireNews: const []),
      ),
    );
    expect(find.text('Strike near Kyiv'), findsAtLeastNWidgets(1));
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Columns'), findsOneWidget);
  });

  testWidgets(
    'shows no-report hint when report is null and not loading (reportId present)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          reportId: 'r1',
          state: const CompareState(isLoading: false, report: null),
        ),
      );
      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    },
  );
}
