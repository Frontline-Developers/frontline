import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/core/providers/bookmark_provider.dart';
import 'package:frontline/core/providers/device_country_provider.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:frontline/features/feed/presentation/providers/feed_provider.dart';
import 'package:frontline/features/feed/presentation/providers/vote_provider.dart';
import 'package:frontline/features/feed/presentation/screens/feed_screen.dart';

class _FakeFeedNotifier extends FeedNotifier {
  final FeedState _initial;
  _FakeFeedNotifier(this._initial);

  @override
  FeedState build() => _initial;
}

class _FakeBookmarkNotifier extends BookmarkNotifier {
  @override
  List<NewsItem> build() => const [];
}

Widget _wrap(FeedState state) => ProviderScope(
  overrides: [
    feedNotifierProvider.overrideWith(() => _FakeFeedNotifier(state)),
    voteProvider.overrideWith((ref, reportId) async => null),
    deviceCountryProvider.overrideWith((ref) async => 'Test Country'),
    bookmarkNotifierProvider.overrideWith(_FakeBookmarkNotifier.new),
  ],
  child: const MaterialApp(home: FeedScreen()),
);

NewsItem _citizen({
  String id = 'c1',
  String title = 'Strike observed',
  ItemStatus? status,
  String? category = 'combat',
}) => NewsItem(
  id: id,
  title: title,
  source: NewsSource.citizen,
  publishedAt: DateTime(2026, 6, 4, 9),
  status: status,
  category: category,
);

NewsItem _wire({String id = 'w1', String title = 'AP News: Update'}) =>
    NewsItem(
      id: id,
      title: title,
      source: NewsSource.wire,
      publishedAt: DateTime(2026, 6, 4, 11),
    );

void main() {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(_wrap(const FeedState()));
    expect(find.byType(FeedScreen), findsOneWidget);
  });

  testWidgets('shows CircularProgressIndicator when isLoading is true', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FeedState(isLoading: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error text when state has error', (tester) async {
    await tester.pumpWidget(_wrap(const FeedState(error: 'Network error')));
    expect(find.text('Network error'), findsOneWidget);
  });

  testWidgets('shows empty message when no items match filter', (tester) async {
    await tester.pumpWidget(
      _wrap(const FeedState(items: [], isLoading: false)),
    );
    expect(find.text('No items match this filter'), findsOneWidget);
  });

  testWidgets('shows citizen report label when citizen item loaded', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(FeedState(items: [_citizen()])));
    await tester.pump();
    expect(find.text('CITIZEN REPORT'), findsOneWidget);
  });

  testWidgets('shows wire news label when wire item loaded', (tester) async {
    await tester.pumpWidget(_wrap(FeedState(items: [_wire()])));
    await tester.pump();
    expect(find.text('WIRE NEWS'), findsOneWidget);
  });

  testWidgets('shows item title in feed', (tester) async {
    await tester.pumpWidget(
      _wrap(FeedState(items: [_citizen(title: 'Shelling near Kharkiv')])),
    );
    await tester.pump();
    expect(find.text('Shelling near Kharkiv'), findsOneWidget);
  });

  testWidgets('filter All shows items without filtering them out', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(FeedState(items: [_citizen(), _wire()])));
    await tester.pump();
    // With 2 items loaded, the empty state must not be shown.
    expect(find.text('No items match this filter'), findsNothing);
    // The first (citizen) card is visible in the test viewport.
    expect(find.text('CITIZEN REPORT'), findsOneWidget);
  });

  testWidgets('filter On the ground shows only citizen items', (tester) async {
    await tester.pumpWidget(_wrap(FeedState(items: [_citizen(), _wire()])));
    await tester.pump();
    await tester.tap(find.text('On the ground'));
    await tester.pump();
    expect(find.text('CITIZEN REPORT'), findsOneWidget);
    expect(find.text('WIRE NEWS'), findsNothing);
  });

  testWidgets('filter Major sources shows only wire items', (tester) async {
    await tester.pumpWidget(_wrap(FeedState(items: [_citizen(), _wire()])));
    await tester.pump();
    await tester.tap(find.text('Major sources'));
    await tester.pump();
    expect(find.text('WIRE NEWS'), findsOneWidget);
    expect(find.text('CITIZEN REPORT'), findsNothing);
  });

  testWidgets('filter Verified shows only verified items', (tester) async {
    final verified = _citizen(id: 'c2', status: ItemStatus.verified);
    final pending = _citizen(id: 'c3', status: ItemStatus.pending);
    await tester.pumpWidget(
      _wrap(FeedState(items: [verified, pending, _wire()])),
    );
    await tester.pump();
    await tester.tap(find.text('Verified'));
    await tester.pump();
    // Only the verified citizen item should show
    expect(find.text('CITIZEN REPORT'), findsOneWidget);
    expect(find.text('WIRE NEWS'), findsNothing);
  });

  testWidgets('filter Verified with no verified items shows empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(FeedState(items: [_citizen(status: ItemStatus.pending)])),
    );
    await tester.pump();
    await tester.tap(find.text('Verified'));
    await tester.pump();
    expect(find.text('No items match this filter'), findsOneWidget);
  });

  testWidgets('shows Frontline app bar', (tester) async {
    await tester.pumpWidget(_wrap(const FeedState()));
    expect(find.text('Frontline'), findsOneWidget);
  });
}
