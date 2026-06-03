import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/my_reports/domain/entities/my_report.dart';
import 'package:frontline/features/my_reports/presentation/providers/my_reports_provider.dart';
import 'package:frontline/features/my_reports/presentation/screens/my_reports_screen.dart';

class _FakeMyReportsNotifier extends MyReportsNotifier {
  final MyReportsState _initial;
  _FakeMyReportsNotifier(this._initial);

  @override
  MyReportsState build() => _initial;
}

Widget _wrap(MyReportsState state) => ProviderScope(
  overrides: [
    myReportsNotifierProvider.overrideWith(() => _FakeMyReportsNotifier(state)),
  ],
  child: const MaterialApp(home: MyReportsScreen()),
);

MyReport _report({
  String id = 'r1',
  String category = 'combat',
  String description = 'Shelling heard near bridge',
  String status = 'pending',
}) => MyReport(
  id: id,
  category: category,
  description: description,
  createdAt: DateTime(2026, 6, 4, 10),
  status: status,
);

void main() {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(_wrap(const MyReportsState()));
    expect(find.byType(MyReportsScreen), findsOneWidget);
  });

  testWidgets('shows CircularProgressIndicator when loading', (tester) async {
    await tester.pumpWidget(_wrap(const MyReportsState(isLoading: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty message when no reports', (tester) async {
    await tester.pumpWidget(
      _wrap(const MyReportsState(reports: [], isLoading: false)),
    );
    expect(find.text('No submissions yet'), findsOneWidget);
  });

  testWidgets(
    'shows empty state even when isLoading is false and reports empty',
    (tester) async {
      await tester.pumpWidget(_wrap(const MyReportsState()));
      expect(find.text('No submissions yet'), findsOneWidget);
    },
  );

  testWidgets('shows report category in list', (tester) async {
    final state = MyReportsState(reports: [_report(category: 'infra')]);
    await tester.pumpWidget(_wrap(state));
    expect(find.text('infra'), findsOneWidget);
  });

  testWidgets('shows report description in list', (tester) async {
    final state = MyReportsState(
      reports: [_report(description: 'Power grid hit near Kharkiv')],
    );
    await tester.pumpWidget(_wrap(state));
    expect(find.text('Power grid hit near Kharkiv'), findsOneWidget);
  });

  testWidgets('shows report status in list', (tester) async {
    final state = MyReportsState(reports: [_report(status: 'confirmed')]);
    await tester.pumpWidget(_wrap(state));
    expect(find.text('confirmed'), findsOneWidget);
  });

  testWidgets('shows multiple reports', (tester) async {
    final state = MyReportsState(
      reports: [
        _report(id: 'r1', category: 'aid'),
        _report(id: 'r2', category: 'alert'),
      ],
    );
    await tester.pumpWidget(_wrap(state));
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}
