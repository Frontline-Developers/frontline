import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';

void main() {
  group('Report', () {
    test('constructs with required fields and schema defaults', () {
      const r = Report(
        category: ReportCategory.combat,
        description: 'desc',
        lat: 50.0,
        lng: 36.2,
      );
      expect(r.status, ReportStatus.pending);
      expect(r.confirmCount, 0);
      expect(r.disputeCount, 0);
      expect(r.isDisputed, false);
      expect(r.exifStripped, false);
      expect(r.mediaUrls, isEmpty);
    });

    test('constructs with full schema fields', () {
      const r = Report(
        id: 'r1',
        userId: 'u1',
        category: ReportCategory.aid,
        description: 'd',
        lat: 1.0,
        lng: 2.0,
        geohash: 'gbsuv',
        mediaUrls: ['url1'],
        status: ReportStatus.confirmed,
        confirmCount: 3,
        disputeCount: 1,
        isDisputed: true,
        exifStripped: true,
      );
      expect(r.id, 'r1');
      expect(r.userId, 'u1');
      expect(r.geohash, 'gbsuv');
      expect(r.status, ReportStatus.confirmed);
      expect(r.confirmCount, 3);
      expect(r.disputeCount, 1);
      expect(r.isDisputed, true);
      expect(r.exifStripped, true);
    });
  });

  group('ReportCategory', () {
    test('has exactly 6 design-spec categories', () {
      expect(ReportCategory.values, hasLength(6));
      expect(
        ReportCategory.values,
        containsAll([
          ReportCategory.combat,
          ReportCategory.aid,
          ReportCategory.alert,
          ReportCategory.displaced,
          ReportCategory.infra,
          ReportCategory.other,
        ]),
      );
    });
  });

  group('ReportStatus', () {
    test('has 4 lifecycle states', () {
      expect(ReportStatus.values, hasLength(4));
      expect(
        ReportStatus.values,
        containsAll([
          ReportStatus.pending,
          ReportStatus.confirmed,
          ReportStatus.disputed,
          ReportStatus.withdrawn,
        ]),
      );
    });
  });
}
