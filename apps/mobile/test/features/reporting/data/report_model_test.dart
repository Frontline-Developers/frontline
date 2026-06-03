import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/data/models/report_model.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';

void main() {
  group('ReportModel.toJson', () {
    test('emits full schema with privacy defaults', () {
      const m = ReportModel(
        userId: 'u1',
        category: ReportCategory.combat,
        description: 'desc',
        lat: 50.024,
        lng: 36.229,
        geohash: 'gbsuv',
        mediaUrls: ['gs://foo/a.jpg'],
        exifStripped: true,
      );
      final json = m.toJson();

      expect(json['userId'], 'u1');
      expect(json['category'], 'combat');
      expect(json['description'], 'desc');

      final loc = json['location'] as GeoPoint;
      expect(loc.latitude, 50.024);
      expect(loc.longitude, 36.229);

      expect(json['geohash'], 'gbsuv');
      expect(json['mediaUrls'], ['gs://foo/a.jpg']);
      expect(json['status'], 'pending');
      expect(json['confirmCount'], 0);
      expect(json['disputeCount'], 0);
      expect(json['isDisputed'], false);
      expect(json['exifStripped'], true);

      // createdAt must be a server timestamp sentinel, not a client-clock value.
      expect(json['createdAt'], isA<FieldValue>());
    });

    test('never emits raw lat/lng fields outside the GeoPoint', () {
      const m = ReportModel(
        userId: 'u1',
        category: ReportCategory.aid,
        description: 'd',
        lat: 1.0,
        lng: 2.0,
      );
      final json = m.toJson();
      expect(json.containsKey('lat'), false);
      expect(json.containsKey('lng'), false);
      expect(json.containsKey('realLat'), false);
      expect(json.containsKey('realLng'), false);
    });

    test('serializes each category to its kebab/lowercase id', () {
      for (final c in ReportCategory.values) {
        final m = ReportModel(
          userId: 'u1',
          category: c,
          description: 'd',
          lat: 0,
          lng: 0,
        );
        expect(m.toJson()['category'], c.name);
      }
    });
  });
}
