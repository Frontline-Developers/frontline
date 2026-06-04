import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';
import 'package:frontline/features/search/domain/usecases/search_items.dart';

NewsItem _item({
  String title = '',
  String? body,
  List<String> locations = const [],
  String? category,
  String? sourceName,
  NewsSource source = NewsSource.citizen,
}) => NewsItem(
  id: 'x',
  title: title,
  body: body,
  locations: locations,
  category: category,
  sourceName: sourceName,
  source: source,
  publishedAt: DateTime(2026),
);

void main() {
  group('searchMatches — text logic', () {
    test('single word matches title', () {
      final item = _item(title: 'Strike on Kharkiv substation');
      expect(searchMatches(item, 'kharkiv', 'all'), isTrue);
    });

    test('single word miss returns false', () {
      final item = _item(title: 'Aid convoy in Odesa');
      expect(searchMatches(item, 'kharkiv', 'all'), isFalse);
    });

    test('multi-word AND — all words present returns true', () {
      final item = _item(title: 'Kharkiv power grid attack');
      expect(searchMatches(item, 'Kharkiv power', 'all'), isTrue);
    });

    test('multi-word AND — one word missing returns false', () {
      final item = _item(title: 'Kharkiv residential attack');
      expect(searchMatches(item, 'kharkiv power', 'all'), isFalse);
    });

    test('match is case-insensitive', () {
      final item = _item(title: 'KHARKIV SUBSTATION');
      expect(searchMatches(item, 'kharkiv substation', 'all'), isTrue);
    });

    test('empty query returns false', () {
      final item = _item(title: 'anything');
      expect(searchMatches(item, '', 'all'), isFalse);
    });

    test('whitespace-only query returns false', () {
      final item = _item(title: 'anything');
      expect(searchMatches(item, '   ', 'all'), isFalse);
    });

    test('word found in body field', () {
      final item = _item(title: 'Report', body: 'drone spotted near river');
      expect(searchMatches(item, 'drone', 'all'), isTrue);
    });

    test('word found in locations list', () {
      final item = _item(title: 'Update', locations: ['Saltivka', 'Kharkiv']);
      expect(searchMatches(item, 'saltivka', 'all'), isTrue);
    });

    test('word found in category', () {
      final item = _item(title: 'Update', category: 'combat');
      expect(searchMatches(item, 'combat', 'all'), isTrue);
    });

    test('word found in sourceName', () {
      final item = _item(
        title: 'Update',
        sourceName: 'Reuters',
        source: NewsSource.wire,
      );
      expect(searchMatches(item, 'reuters', 'all'), isTrue);
    });

    test('words spread across title and body both match', () {
      final item = _item(title: 'Kharkiv update', body: 'power restored');
      expect(searchMatches(item, 'kharkiv power', 'all'), isTrue);
    });
  });

  group('searchMatches — scope filter', () {
    test('scope all — citizen item matches', () {
      final item = _item(title: 'report', source: NewsSource.citizen);
      expect(searchMatches(item, 'report', 'all'), isTrue);
    });

    test('scope all — wire item matches', () {
      final item = _item(title: 'report', source: NewsSource.wire);
      expect(searchMatches(item, 'report', 'all'), isTrue);
    });

    test('scope citizen — citizen item matches', () {
      final item = _item(title: 'report', source: NewsSource.citizen);
      expect(searchMatches(item, 'report', 'citizen'), isTrue);
    });

    test('scope citizen — wire item excluded', () {
      final item = _item(title: 'report', source: NewsSource.wire);
      expect(searchMatches(item, 'report', 'citizen'), isFalse);
    });

    test('scope sources — wire item matches', () {
      final item = _item(title: 'report', source: NewsSource.wire);
      expect(searchMatches(item, 'report', 'sources'), isTrue);
    });

    test('scope sources — citizen item excluded', () {
      final item = _item(title: 'report', source: NewsSource.citizen);
      expect(searchMatches(item, 'report', 'sources'), isFalse);
    });
  });
}
