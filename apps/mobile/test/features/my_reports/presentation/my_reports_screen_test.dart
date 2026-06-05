import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/comments/presentation/providers/comments_provider.dart';
import 'package:frontline/features/my_reports/domain/entities/my_report.dart';
import 'package:frontline/features/my_reports/presentation/providers/my_reports_provider.dart';
import 'package:frontline/features/my_reports/presentation/screens/my_reports_screen.dart';

// ── Fake notifier ─────────────────────────────────────────────────────────────

class _FakeMyReportsNotifier extends MyReportsNotifier {
  final MyReportsState _initial;
  _FakeMyReportsNotifier(this._initial);

  @override
  MyReportsState build() => _initial;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(MyReportsState state) => ProviderScope(
  overrides: [
    myReportsNotifierProvider.overrideWith(() => _FakeMyReportsNotifier(state)),
    // _ActionRow is a ConsumerWidget that watches commentsStreamProvider.
    // Override to avoid Firebase calls in tests.
    commentsStreamProvider.overrideWith((ref, id) => Stream.value(const [])),
  ],
  child: const MaterialApp(home: MyReportsScreen()),
);

MyReport _report({
  String id = 'r1',
  String title = 'Strike on substation, Saltivka district',
  String body = 'Heard the impact at 03:42.',
  String category = 'infra',
  String location = 'Kharkiv · Saltivka',
  String status = 'pending',
  int confirms = 10,
  int flags = 0,
  int views = 500,
  int commentCount = 3,
  String token = 'abcd-1234-efgh-5678',
}) => MyReport(
  id: id,
  title: title,
  body: body,
  category: category,
  location: location,
  status: status,
  confirms: confirms,
  flags: flags,
  views: views,
  commentCount: commentCount,
  token: token,
  submittedAt: DateTime(2025, 3, 18, 3, 46),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MyReportsScreen — render', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrap(const MyReportsState()));
      expect(find.byType(MyReportsScreen), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(_wrap(const MyReportsState(isLoading: true)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no reports', (tester) async {
      await tester.pumpWidget(
        _wrap(const MyReportsState(reports: [], isLoading: false)),
      );
      expect(find.textContaining('No submissions yet'), findsOneWidget);
    });
  });

  group('MyReportsScreen — stats header', () {
    testWidgets('shows submission count', (tester) async {
      final state = MyReportsState(
        reports: [
          _report(id: 'r1'),
          _report(id: 'r2'),
        ],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.text('2 submissions'), findsOneWidget);
    });

    testWidgets('shows "1 submission" (singular)', (tester) async {
      final state = MyReportsState(reports: [_report()]);
      await tester.pumpWidget(_wrap(state));
      expect(find.text('1 submission'), findsOneWidget);
    });

    testWidgets('shows VERIFIED stat label', (tester) async {
      final state = MyReportsState(
        reports: [
          _report(status: 'confirmed'),
          _report(id: 'r2'),
        ],
      );
      await tester.pumpWidget(_wrap(state));
      // 'VERIFIED' appears in both the stat column label and the card badge.
      expect(find.text('VERIFIED'), findsWidgets);
    });

    testWidgets('shows CONFIRMS stat label', (tester) async {
      final state = MyReportsState(reports: [_report(confirms: 50)]);
      await tester.pumpWidget(_wrap(state));
      expect(find.text('CONFIRMS'), findsOneWidget);
    });
  });

  group('MyReportsScreen — filter tabs', () {
    testWidgets('shows All, Verified, Pending, Disputed filter tabs', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MyReportsState()));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Disputed'), findsOneWidget);
    });

    testWidgets('tapping Verified filter shows only verified reports', (
      tester,
    ) async {
      final state = MyReportsState(
        reports: [
          _report(id: 'r1', title: 'Verified report', status: 'confirmed'),
          _report(id: 'r2', title: 'Pending report', status: 'pending'),
        ],
      );
      await tester.pumpWidget(_wrap(state));
      await tester.tap(find.text('Verified'));
      await tester.pump();
      expect(find.textContaining('Verified report'), findsOneWidget);
      expect(find.textContaining('Pending report'), findsNothing);
    });

    testWidgets('disputed empty state shows positive message', (tester) async {
      await tester.pumpWidget(_wrap(const MyReportsState()));
      await tester.tap(find.text('Disputed'));
      await tester.pump();
      expect(find.textContaining('No disputed'), findsOneWidget);
    });
  });

  group('MyReportsScreen — report cards', () {
    testWidgets('shows report title', (tester) async {
      final state = MyReportsState(
        reports: [_report(title: 'Water pressure dropped')],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('Water pressure dropped'), findsOneWidget);
    });

    testWidgets('shows location', (tester) async {
      final state = MyReportsState(
        reports: [_report(location: 'Kharkiv · Centralnyi')],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.text('Kharkiv · Centralnyi'), findsOneWidget);
    });

    testWidgets('trash icon only visible on disputed reports', (tester) async {
      final state = MyReportsState(
        reports: [
          _report(id: 'r1', status: 'disputed'),
          _report(id: 'r2', status: 'confirmed'),
          _report(id: 'r3', status: 'pending'),
        ],
      );
      await tester.pumpWidget(_wrap(state));
      // Only one trash icon for the one disputed report
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('verify meter shown for pending reports', (tester) async {
      final state = MyReportsState(
        reports: [_report(status: 'pending', confirms: 10, flags: 5)],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('verified'), findsWidgets);
    });

    testWidgets('verify meter shown for disputed reports', (tester) async {
      final state = MyReportsState(
        reports: [_report(status: 'disputed', confirms: 5, flags: 20)],
      );
      await tester.pumpWidget(_wrap(state));
      expect(find.textContaining('flagged'), findsWidgets);
    });

    testWidgets('verify meter NOT shown for verified reports', (tester) async {
      final state = MyReportsState(
        reports: [_report(status: 'confirmed', confirms: 50, flags: 0)],
      );
      await tester.pumpWidget(_wrap(state));
      // No "flagged" text for verified cards
      expect(find.text('0 flagged'), findsNothing);
    });
  });

  group('MyReportsScreen — loading guard', () {
    testWidgets('does not show list while loading', (tester) async {
      final state = MyReportsState(isLoading: true, reports: [_report()]);
      await tester.pumpWidget(_wrap(state));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Strike'), findsNothing);
    });
  });
}
