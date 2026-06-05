import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/core/providers/bookmark_provider.dart';
import 'package:frontline/features/bookmarks/presentation/screens/bookmarks_screen.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

class _FakeBookmarkNotifier extends BookmarkNotifier {
  final List<NewsItem> _initial;
  _FakeBookmarkNotifier([this._initial = const []]);

  @override
  List<NewsItem> build() => _initial;

  @override
  Future<void> toggle(NewsItem item) async {
    final next = List<NewsItem>.of(state);
    if (next.any((i) => i.id == item.id)) {
      next.removeWhere((i) => i.id == item.id);
    } else {
      next.insert(0, item);
    }
    state = next;
  }
}

Widget _wrap(List<NewsItem> items) => ProviderScope(
  overrides: [
    bookmarkNotifierProvider.overrideWith(() => _FakeBookmarkNotifier(items)),
  ],
  child: const MaterialApp(home: BookmarksScreen()),
);

NewsItem _citizen({String id = 'c1', String title = 'Strike near Kyiv'}) =>
    NewsItem(
      id: id,
      title: title,
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 1, 1),
    );

NewsItem _wire({String id = 'w1', String title = 'AP: Peace talks stall'}) =>
    NewsItem(
      id: id,
      title: title,
      source: NewsSource.wire,
      publishedAt: DateTime(2026, 1, 2),
    );

void main() {
  group('BookmarksScreen — render', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrap([]));
      expect(find.byType(BookmarksScreen), findsOneWidget);
    });

    testWidgets('shows Saved header', (tester) async {
      await tester.pumpWidget(_wrap([]));
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('shows All / On the ground / Major sources filter tabs', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([]));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('On the ground'), findsOneWidget);
      expect(find.text('Major sources'), findsOneWidget);
    });
  });

  group('BookmarksScreen — empty state', () {
    testWidgets('empty All — shows bookmark_border icon and prompt', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([]));
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.textContaining('No saved items yet'), findsOneWidget);
    });

    testWidgets('empty citizen filter — shows specific message', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([_wire()]));
      await tester.pump();
      await tester.tap(find.text('On the ground'));
      await tester.pump();
      expect(find.text('No citizen reports saved.'), findsOneWidget);
    });

    testWidgets('empty wire filter — shows specific message', (tester) async {
      await tester.pumpWidget(_wrap([_citizen()]));
      await tester.pump();
      await tester.tap(find.text('Major sources'));
      await tester.pump();
      expect(find.text('No wire news saved.'), findsOneWidget);
    });
  });

  group('BookmarksScreen — loaded state', () {
    testWidgets('shows item count in header', (tester) async {
      await tester.pumpWidget(_wrap([_citizen(), _wire()]));
      await tester.pump();
      // Count "2" appears in the header and in the All filter tab badge.
      expect(find.text('2'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows all item titles in All tab', (tester) async {
      await tester.pumpWidget(_wrap([_citizen(), _wire()]));
      await tester.pump();
      expect(find.text('Strike near Kyiv'), findsOneWidget);
      expect(find.text('AP: Peace talks stall'), findsOneWidget);
    });

    testWidgets('On the ground filter shows only citizen items', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([_citizen(), _wire()]));
      await tester.pump();
      await tester.tap(find.text('On the ground'));
      await tester.pump();
      expect(find.text('Strike near Kyiv'), findsOneWidget);
      expect(find.text('AP: Peace talks stall'), findsNothing);
    });

    testWidgets('Major sources filter shows only wire items', (tester) async {
      await tester.pumpWidget(_wrap([_citizen(), _wire()]));
      await tester.pump();
      await tester.tap(find.text('Major sources'));
      await tester.pump();
      expect(find.text('AP: Peace talks stall'), findsOneWidget);
      expect(find.text('Strike near Kyiv'), findsNothing);
    });

    testWidgets('each card shows a filled bookmark icon', (tester) async {
      await tester.pumpWidget(_wrap([_citizen()]));
      await tester.pump();
      // Card bookmark button icon is size 18; header bookmark icon is size 20.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.bookmark && w.size == 18,
        ),
        findsOneWidget,
      );
    });
  });

  group('BookmarksScreen — remove action', () {
    testWidgets('tapping bookmark icon removes item from list', (tester) async {
      await tester.pumpWidget(_wrap([_citizen()]));
      await tester.pump();
      expect(find.text('Strike near Kyiv'), findsOneWidget);

      // Card bookmark button icon is size 18; header bookmark icon is size 20.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.bookmark && w.size == 18,
        ),
      );
      await tester.pump();

      expect(find.text('Strike near Kyiv'), findsNothing);
      expect(find.textContaining('No saved items yet'), findsOneWidget);
    });
  });
}
