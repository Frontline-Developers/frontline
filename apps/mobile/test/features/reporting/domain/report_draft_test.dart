import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';

void main() {
  group('ReportDraft.isDescribeValid', () {
    test('false when description is 8 chars or fewer', () {
      const d = ReportDraft(
        description: '12345678',
        category: ReportCategory.aid,
      );
      expect(d.isDescribeValid, false);
    });

    test('false when description is long enough but category null', () {
      const d = ReportDraft(description: 'long enough text');
      expect(d.isDescribeValid, false);
    });

    test('false when whitespace-only padded short description', () {
      const d = ReportDraft(
        description: '   ab    ',
        category: ReportCategory.combat,
      );
      expect(d.isDescribeValid, false);
    });

    test('true when description >8 chars and category set', () {
      const d = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
      );
      expect(d.isDescribeValid, true);
    });
  });

  group('ReportDraft.isLocationValid', () {
    test('false when locationLabel is empty', () {
      const d = ReportDraft(lat: 1.0, lng: 2.0);
      expect(d.isLocationValid, false);
    });

    test('false when lat/lng missing', () {
      const d = ReportDraft(locationLabel: 'Kharkiv');
      expect(d.isLocationValid, false);
    });

    test('true when label + both coords present', () {
      const d = ReportDraft(locationLabel: 'Kharkiv', lat: 50.0, lng: 36.2);
      expect(d.isLocationValid, true);
    });
  });

  group('ReportDraft.isEvidenceValid', () {
    test('always true (evidence is optional)', () {
      const empty = ReportDraft();
      expect(empty.isEvidenceValid, true);
    });
  });

  group('ReportDraft.copyWith', () {
    test('replaces only specified fields, preserves others', () {
      const d = ReportDraft(
        description: 'orig',
        category: ReportCategory.aid,
        locationLabel: 'Kyiv',
        lat: 1.0,
        lng: 2.0,
      );
      final updated = d.copyWith(description: 'new');
      expect(updated.description, 'new');
      expect(updated.category, ReportCategory.aid);
      expect(updated.locationLabel, 'Kyiv');
      expect(updated.lat, 1.0);
      expect(updated.lng, 2.0);
    });

    test('sentinel pattern allows clearing nullable fields', () {
      const d = ReportDraft(
        category: ReportCategory.aid,
        lat: 1.0,
        lng: 2.0,
        timeObserved: '03:42',
      );
      final cleared = d.copyWith(category: null, timeObserved: null);
      expect(cleared.category, isNull);
      expect(cleared.timeObserved, isNull);
      expect(cleared.lat, 1.0); // preserved
    });
  });
}
