import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/feed/data/models/news_item_model.dart';
import 'package:frontline/features/feed/domain/entities/news_item.dart';

void main() {
  group('NewsItemModel.fromJson', () {
    test('maps wire_news Firestore document data to a NewsItem entity', () {
      final data = {
        'title': 'Ukraine convoy advances near frontline',
        'url': 'https://example.com/article',
        'publishedAt': Timestamp.fromDate(
          DateTime.utc(2025, 12, 31, 23, 59, 59),
        ),
        'sourceName': 'Reuters',
        'imageUrl': 'https://example.com/image.jpg',
        'locations': ['kyiv', 'kharkiv'],
        'themes': ['combat', 'alert'],
        'tone': 12,
      };

      final model = NewsItemModel.fromJson('doc-123', data);
      final entity = model.toEntity();

      expect(entity.id, 'doc-123');
      expect(entity.title, 'Ukraine convoy advances near frontline');
      expect(entity.url, 'https://example.com/article');
      expect(entity.source, NewsSource.wire);
      expect(
        entity.publishedAt.toUtc(),
        DateTime.utc(2025, 12, 31, 23, 59, 59),
      );
      expect(entity.sourceName, 'Reuters');
      expect(entity.imageUrl, 'https://example.com/image.jpg');
      expect(entity.locations, ['kyiv', 'kharkiv']);
      expect(entity.themes, ['combat', 'alert']);
      expect(entity.tone, 12);
    });

    test('handles missing optional wire_news enrichment fields', () {
      final data = {
        'title': 'Ukraine convoy advances near frontline',
        'publishedAt': Timestamp.fromDate(
          DateTime.utc(2025, 12, 31, 23, 59, 59),
        ),
      };

      final model = NewsItemModel.fromJson('doc-456', data);
      final entity = model.toEntity();

      expect(entity.id, 'doc-456');
      expect(entity.url, isNull);
      expect(entity.sourceName, isNull);
      expect(entity.imageUrl, isNull);
      expect(entity.locations, isEmpty);
      expect(entity.themes, isEmpty);
      expect(entity.tone, 0);
    });
  });
}
