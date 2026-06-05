import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/core/providers/vote_provider.dart';
import 'package:frontline/features/comments/presentation/providers/comments_provider.dart';
import 'package:frontline/features/feed/data/datasources/vote_datasource.dart';
import 'package:frontline/features/my_reports/domain/entities/my_report.dart';
import 'package:frontline/features/my_reports/presentation/screens/report_detail_screen.dart';

// ── Test doubles ──────────────────────────────────────────────────────────────

class _FakeVoteDatasource implements VoteDatasource {
  @override
  Future<String?> getUserVote(String reportId) async => null;

  @override
  Future<void> castVote(String reportId, String? type) async {}

  @override
  Stream<VoteCounts> watchVoteCounts(String reportId) =>
      Stream.value((confirm: 0, dispute: 0));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {List<Comment> comments = const []}) {
  return ProviderScope(
    overrides: [
      voteProvider.overrideWith((ref, id) async => null),
      commentsStreamProvider.overrideWith((ref, id) => Stream.value(comments)),
      voteDatasourceProvider.overrideWith((_) => _FakeVoteDatasource()),
    ],
    child: MaterialApp(home: child),
  );
}

MyReport _report({String status = 'pending', List<String> photos = const []}) =>
    MyReport(
      id: 'r1',
      title: 'Strike on substation',
      body: 'Heard the impact at 03:42.',
      category: 'combat',
      location: 'Kyiv',
      status: status,
      token: 'tok123456789',
      submittedAt: DateTime(2024),
      confirms: 3,
      flags: 1,
      photos: photos,
    );

Comment _comment() => Comment(
  id: 'c1',
  type: CommentType.confirm,
  text: 'I confirm this from nearby.',
  authorToken: 'abcd',
  createdAt: DateTime(2024),
  upvotes: 2,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Empty state
  testWidgets('shows "Report not found" when report is null', (tester) async {
    await tester.pumpWidget(_wrap(const MyReportDetailScreen(reportId: 'x')));
    await tester.pump();
    expect(find.text('Report not found'), findsOneWidget);
  });

  // Render
  testWidgets('renders without error when report is provided', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.byType(MyReportDetailScreen), findsOneWidget);
  });

  testWidgets('shows CITIZEN REPORT label', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('CITIZEN REPORT'), findsOneWidget);
  });

  // Hero badges
  testWidgets('shows ON THE GROUND badge', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('ON THE GROUND'), findsOneWidget);
  });

  testWidgets('shows uppercase category badge', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('COMBAT'), findsOneWidget);
  });

  testWidgets('shows PENDING status badge for pending report', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets('shows VERIFIED badge for verified report', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MyReportDetailScreen(
          reportId: 'r1',
          report: _report(status: 'verified'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('VERIFIED'), findsOneWidget);
  });

  // Title + body
  testWidgets('shows report title', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('Strike on substation'), findsOneWidget);
  });

  testWidgets('shows report body text', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.textContaining('Heard the impact at 03:42'), findsOneWidget);
  });

  // Verification panel
  testWidgets('shows Community verification panel', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('Community verification'), findsOneWidget);
  });

  testWidgets('shows Confirm vote button', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('shows Flag vote button', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('Flag'), findsOneWidget);
  });

  // Positive action — active vote state
  testWidgets(
    'Confirm button uses filled icon when user already voted confirm',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voteProvider.overrideWith((ref, id) async => 'confirm'),
            commentsStreamProvider.overrideWith(
              (ref, id) => Stream.value(const []),
            ),
            voteDatasourceProvider.overrideWith((_) => _FakeVoteDatasource()),
          ],
          child: MaterialApp(
            home: MyReportDetailScreen(reportId: 'r1', report: _report()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    },
  );

  // Discussion — empty
  testWidgets('shows "No comments yet" when discussion is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('No comments yet'), findsOneWidget);
  });

  // Discussion — with comments
  testWidgets('shows comment preview text when comments are present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MyReportDetailScreen(reportId: 'r1', report: _report()),
        comments: [_comment()],
      ),
    );
    await tester.pump();
    expect(find.textContaining('I confirm this from nearby.'), findsOneWidget);
  });

  testWidgets('shows "View all" link when comments are present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MyReportDetailScreen(reportId: 'r1', report: _report()),
        comments: [_comment()],
      ),
    );
    await tester.pump();
    expect(find.textContaining('View all'), findsOneWidget);
  });

  // Action bar
  testWidgets('shows Comment button in action bar', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('Comment'), findsOneWidget);
  });

  testWidgets('shows Share button in action bar', (tester) async {
    await tester.pumpWidget(
      _wrap(MyReportDetailScreen(reportId: 'r1', report: _report())),
    );
    await tester.pump();
    expect(find.text('Share'), findsOneWidget);
  });
}
