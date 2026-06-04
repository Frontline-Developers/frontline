import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/reporting/domain/entities/report.dart';

void main() {
  group('ReportDraft.isDescribeValid', () {
    test('false when description is under 10 chars', () {
      const d = ReportDraft(
        description: '123456789', // 9 chars — one under the minimum
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

    test('true when description >= 10 chars and category set', () {
      const d = ReportDraft(
        description: 'a drone hit the substation',
        category: ReportCategory.combat,
      );
      expect(d.isDescribeValid, true);
    });
  });

  group('ReportDraft.isLocationValid', () {
    test('true when both coords present (label optional)', () {
      const d = ReportDraft(lat: 1.0, lng: 2.0);
      expect(d.isLocationValid, true);
    });

    test('false when lat/lng missing', () {
      const d = ReportDraft(locationLabel: 'Kharkiv');
      expect(d.isLocationValid, false);
    });

    test('false when only lat present', () {
      const d = ReportDraft(lat: 50.0);
      expect(d.isLocationValid, false);
    });

    test('true when label + both coords present', () {
      const d = ReportDraft(locationLabel: 'Kharkiv', lat: 50.0, lng: 36.2);
      expect(d.isLocationValid, true);
    });
  });

  group('ReportDraft.isEvidenceValid', () {
    test('false when no photos attached', () {
      const empty = ReportDraft();
      expect(empty.isEvidenceValid, false);
    });

    test('true when one photo attached', () {
      final d = ReportDraft(mediaBytes: [Uint8List.fromList([1])]);
      expect(d.isEvidenceValid, true);
    });

    test('true when exactly maxPhotos photos attached', () {
      final d = ReportDraft(
        mediaBytes: List.generate(
          ReportDraft.maxPhotos,
          (_) => Uint8List.fromList([1]),
        ),
      );
      expect(d.isEvidenceValid, true);
    });

    test('false when more than maxPhotos photos attached', () {
      final d = ReportDraft(
        mediaBytes: List.generate(
          ReportDraft.maxPhotos + 1,
          (_) => Uint8List.fromList([1]),
        ),
      );
      expect(d.isEvidenceValid, false);
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
