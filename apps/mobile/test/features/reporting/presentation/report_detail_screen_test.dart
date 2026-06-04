import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/comments/presentation/providers/comments_provider.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:frontline/features/feed/presentation/providers/vote_provider.dart';
import 'package:frontline/features/reporting/presentation/screens/report_detail_screen.dart';

// ── Test doubles ──────────────────────────────────────────────────────────────

Widget _wrap(
  NewsItem item, {
  List<Comment> comments = const [],
  String? userVote,
}) => ProviderScope(
  overrides: [
    voteProvider.overrideWith((ref, id) async => userVote),
    commentsStreamProvider.overrideWith((ref, id) => Stream.value(comments)),
  ],
  child: MaterialApp(home: ReportDetailScreen(item: item)),
);

// ── Test fixtures ─────────────────────────────────────────────────────────────

final _citizenItem = NewsItem(
  id: 'r1',
  title: 'Strike on substation, Saltivka district',
  body:
      'Heard the impact at 03:42. Transformer building on Pavlova is on fire.',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 6, 4, 9),
  category: 'combat',
  status: ItemStatus.verified,
  confirmCount: 34,
  disputeCount: 2,
);

final _disputedItem = NewsItem(
  id: 'r2',
  title: 'Unconfirmed movement near Bakhmut',
  body: 'Several sources claim troop activity.',
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 6, 4, 8),
  category: 'combat',
  status: ItemStatus.disputed,
  confirmCount: 3,
  disputeCount: 8,
);

final _wireItem = NewsItem(
  id: 'w1',
  title: 'Reuters: Substation attack confirmed',
  body: 'A Ukrainian power substation was attacked overnight near Kharkiv.',
  url: 'https://reuters.com/article/ukraine-1',
  source: NewsSource.wire,
  publishedAt: DateTime(2026, 6, 4, 10),
  sourceName: 'Reuters',
);

final _wireItemNoUrl = NewsItem(
  id: 'w2',
  title: 'AP: Aid convoy delayed',
  body: 'An aid convoy has been delayed due to road conditions.',
  source: NewsSource.wire,
  publishedAt: DateTime(2026, 6, 4, 11),
  sourceName: 'Associated Press',
);

Comment _comment({
  String id = 'c1',
  String text = 'I can confirm from two streets over.',
  String authorToken = 'h8m2ab',
}) => Comment(
  id: id,
  type: CommentType.confirm,
  text: text,
  authorToken: authorToken,
  createdAt: DateTime(2026, 6, 4, 9, 5),
  upvotes: 3,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // 1. Render
  testWidgets('renders without error for a citizen item', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.byType(ReportDetailScreen), findsOneWidget);
  });

  // 2. Source label — citizen
  testWidgets('shows CITIZEN REPORT label for citizen source', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.text('CITIZEN REPORT'), findsOneWidget);
  });

  // 3. Category badge
  testWidgets('shows uppercase category badge for citizen item', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.text('COMBAT'), findsOneWidget);
  });

  // 4. VERIFIED status badge
  testWidgets('shows VERIFIED badge when status is verified', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.text('VERIFIED'), findsOneWidget);
  });

  // 5. DISPUTED banner
  testWidgets('shows DISPUTED badge when status is disputed', (tester) async {
    await tester.pumpWidget(_wrap(_disputedItem));
    await tester.pump();
    expect(find.text('DISPUTED'), findsOneWidget);
  });

  // 6. Body text
  testWidgets('shows body description text for citizen item', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.textContaining('Heard the impact at 03:42'), findsOneWidget);
  });

  // 7. Confirm count in verification panel
  testWidgets('shows confirm count in community verification panel', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.textContaining('34 verified'), findsOneWidget);
  });

  // 8. Dispute count in verification panel
  testWidgets('shows dispute count in community verification panel', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.textContaining('2 flagged'), findsOneWidget);
  });

  // 9. Confirm button present and tappable
  testWidgets('shows Confirm button for citizen item', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.text('Confirm'), findsOneWidget);
  });

  // 10. Flag button present and tappable
  testWidgets('shows Flag button for citizen item', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.text('Flag'), findsOneWidget);
  });

  // 11. No verify panel for wire
  testWidgets('does not show Confirm/Flag buttons for wire item', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_wireItem));
    await tester.pump();
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('Flag'), findsNothing);
  });

  // 12. Source name for wire
  testWidgets('shows sourceName label for wire item', (tester) async {
    await tester.pumpWidget(_wrap(_wireItem));
    await tester.pump();
    expect(find.text('Reuters'), findsOneWidget);
  });

  // 13. "Read full article" button for wire with url
  testWidgets('shows Read full article button for wire item with url', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_wireItem));
    await tester.pump();
    expect(find.text('Read full article'), findsOneWidget);
  });

  // 13b. No "Read full article" when url is null
  testWidgets('does not show Read full article when wire url is null', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_wireItemNoUrl));
    await tester.pump();
    expect(find.text('Read full article'), findsNothing);
  });

  // 14. Compare button for citizen
  testWidgets('shows Compare button for citizen item', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.textContaining('Compare'), findsOneWidget);
  });

  // 15. Compare button for wire
  testWidgets('shows Compare button for wire item', (tester) async {
    await tester.pumpWidget(_wrap(_wireItem));
    await tester.pump();
    expect(find.textContaining('Compare'), findsOneWidget);
  });

  // 16. Discussion section shows preview comment
  testWidgets('shows first comment text in discussion preview', (tester) async {
    final comments = [_comment(text: 'I can confirm from two streets over.')];
    await tester.pumpWidget(_wrap(_citizenItem, comments: comments));
    await tester.pump();
    expect(
      find.textContaining('I can confirm from two streets over.'),
      findsOneWidget,
    );
  });

  // 17. Empty comments state
  testWidgets('shows no comments message when discussion is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(find.text('No comments yet'), findsOneWidget);
  });

  // 18. Confirm button is active when user already confirmed
  testWidgets('Confirm button shows filled icon when user vote is confirm', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_citizenItem, userVote: 'confirm'));
    await tester.pump();
    // Active state uses check_circle (filled); inactive uses check_circle_outline.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  // 19. Title shown for both source types
  testWidgets('shows item title for citizen item', (tester) async {
    await tester.pumpWidget(_wrap(_citizenItem));
    await tester.pump();
    expect(
      find.text('Strike on substation, Saltivka district'),
      findsOneWidget,
    );
  });

  testWidgets('shows item title for wire item', (tester) async {
    await tester.pumpWidget(_wrap(_wireItem));
    await tester.pump();
    expect(find.text('Reuters: Substation attack confirmed'), findsOneWidget);
  });
}
