import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

void main() {
  group('NewsItem', () {
    final base = NewsItem(
      id: 'item-1',
      title: 'Shelling reported near Kharkiv',
      source: NewsSource.citizen,
      publishedAt: DateTime(2026, 6, 4, 9, 30),
    );

    test('stores required fields', () {
      expect(base.id, 'item-1');
      expect(base.title, 'Shelling reported near Kharkiv');
      expect(base.source, NewsSource.citizen);
    });

    test('optional fields default to null / empty', () {
      expect(base.body, isNull);
      expect(base.url, isNull);
      expect(base.category, isNull);
      expect(base.status, isNull);
      expect(base.mediaUrls, isEmpty);
    });

    test('confirmCount and disputeCount default to 0', () {
      expect(base.confirmCount, 0);
      expect(base.disputeCount, 0);
    });

    test('wire source item', () {
      final wire = NewsItem(
        id: 'wire-1',
        title: 'Reuters: Strike confirmed',
        source: NewsSource.wire,
        publishedAt: DateTime(2026, 6, 4, 11),
        body: 'Artillery hit infrastructure',
        url: 'https://example.com/article',
      );
      expect(wire.source, NewsSource.wire);
      expect(wire.url, 'https://example.com/article');
    });

    test('stores vote counts and status', () {
      final verified = NewsItem(
        id: 'item-2',
        title: 'Confirmed strike',
        source: NewsSource.citizen,
        publishedAt: DateTime(2026, 6, 4, 12),
        status: ItemStatus.verified,
        confirmCount: 10,
        disputeCount: 2,
      );
      expect(verified.status, ItemStatus.verified);
      expect(verified.confirmCount, 10);
      expect(verified.disputeCount, 2);
    });
  });

  group('NewsSource enum', () {
    test('has citizen and wire values', () {
      expect(
        NewsSource.values,
        containsAll([NewsSource.citizen, NewsSource.wire]),
      );
    });
  });

  group('ItemStatus enum', () {
    test('has pending, verified, disputed values', () {
      expect(
        ItemStatus.values,
        containsAll([
          ItemStatus.pending,
          ItemStatus.verified,
          ItemStatus.disputed,
        ]),
      );
    });
  });
}
