import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/map/data/models/map_report_model.dart';
import 'package:frontline/features/map/domain/entities/map_report.dart';

Map<String, dynamic> _baseJson() => {
  'location': const GeoPoint(50.45, 30.52),
  'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
  'description': 'Strike on bridge',
  'category': 'combat',
  'status': 'confirmed',
  'locationLabel': 'Kyiv',
};

void main() {
  group('MapReportModel.fromJson — standard Firestore document', () {
    test('reads lat and lng from GeoPoint', () {
      final model = MapReportModel.fromJson('doc-1', _baseJson());
      expect(model.lat, 50.45);
      expect(model.lng, 30.52);
    });

    test('reads description field as title', () {
      final model = MapReportModel.fromJson('doc-1', _baseJson());
      expect(model.title, 'Strike on bridge');
    });

    test('falls back to title field when description is absent', () {
      final json = _baseJson()
        ..remove('description')
        ..['title'] = 'Fallback';
      final model = MapReportModel.fromJson('doc-1', json);
      expect(model.title, 'Fallback');
    });

    test(
      'title is empty string when both description and title are absent',
      () {
        final json = _baseJson()
          ..remove('description')
          ..remove('title');
        final model = MapReportModel.fromJson('doc-1', json);
        expect(model.title, '');
      },
    );

    test('reads category field', () {
      final model = MapReportModel.fromJson('doc-1', _baseJson());
      expect(model.category, 'combat');
    });

    test('defaults category to "other" when absent', () {
      final json = _baseJson()..remove('category');
      final model = MapReportModel.fromJson('doc-1', json);
      expect(model.category, 'other');
    });

    test('reads locationLabel when present', () {
      final model = MapReportModel.fromJson('doc-1', _baseJson());
      expect(model.locationLabel, 'Kyiv');
    });

    test('defaults locationLabel to empty string when absent', () {
      final json = _baseJson()..remove('locationLabel');
      final model = MapReportModel.fromJson('doc-1', json);
      expect(model.locationLabel, '');
    });

    test('reads status field', () {
      final model = MapReportModel.fromJson('doc-1', _baseJson());
      expect(model.status, 'confirmed');
    });

    test('defaults status to "pending" when absent', () {
      final json = _baseJson()..remove('status');
      final model = MapReportModel.fromJson('doc-1', json);
      expect(model.status, 'pending');
    });

    test('reads createdAt from Timestamp', () {
      final model = MapReportModel.fromJson('doc-1', _baseJson());
      expect(model.createdAt, DateTime(2026, 1, 1));
    });

    test('id is assigned from first argument', () {
      final model = MapReportModel.fromJson('doc-99', _baseJson());
      expect(model.id, 'doc-99');
    });
  });

  group('MapReportModel.toEntity', () {
    late MapReportModel model;

    setUp(() {
      model = MapReportModel.fromJson('id1', _baseJson());
    });

    test('returns MapReport with matching id', () {
      final entity = model.toEntity();
      expect(entity, isA<MapReport>());
      expect(entity.id, 'id1');
    });

    test('returns MapReport with matching lat and lng', () {
      final entity = model.toEntity();
      expect(entity.lat, 50.45);
      expect(entity.lng, 30.52);
    });

    test('returns MapReport with matching title', () {
      final entity = model.toEntity();
      expect(entity.title, 'Strike on bridge');
    });

    test('returns MapReport with matching category', () {
      final entity = model.toEntity();
      expect(entity.category, 'combat');
    });

    test('returns MapReport with matching locationLabel', () {
      final entity = model.toEntity();
      expect(entity.locationLabel, 'Kyiv');
    });

    test('returns MapReport with matching status', () {
      final entity = model.toEntity();
      expect(entity.status, 'confirmed');
    });

    test('returns MapReport with matching createdAt', () {
      final entity = model.toEntity();
      expect(entity.createdAt, DateTime(2026, 1, 1));
    });
  });
}
