import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/my_reports/domain/entities/my_report.dart';

MyReport _build({
  String id = 'rpt-abc',
  String title = 'Strike on substation',
  String body = 'Heard the impact at 03:42.',
  String category = 'infra',
  String location = 'Kharkiv · Saltivka',
  String status = 'pending',
  String token = 'abcd-1234-efgh-5678',
  int confirms = 0,
  int flags = 0,
  int views = 0,
  int commentCount = 0,
  List<String> photos = const [],
}) => MyReport(
  id: id,
  title: title,
  body: body,
  category: category,
  location: location,
  status: status,
  token: token,
  submittedAt: DateTime(2025, 3, 18, 3, 46),
  confirms: confirms,
  flags: flags,
  views: views,
  commentCount: commentCount,
  photos: photos,
);

void main() {
  group('MyReport — field storage', () {
    test('stores all required fields', () {
      final r = _build();
      expect(r.id, 'rpt-abc');
      expect(r.title, 'Strike on substation');
      expect(r.body, 'Heard the impact at 03:42.');
      expect(r.category, 'infra');
      expect(r.location, 'Kharkiv · Saltivka');
      expect(r.status, 'pending');
      expect(r.token, 'abcd-1234-efgh-5678');
    });

    test('defaults snippet to body when not provided', () {
      final r = _build(body: 'Full body text here.');
      expect(r.snippet, 'Full body text here.');
    });

    test('stores separate snippet when provided', () {
      final r = MyReport(
        id: 'r',
        title: 't',
        body: 'Full long body',
        snippet: 'Short snippet',
        category: 'aid',
        location: 'Kyiv',
        status: 'pending',
        token: 'aaaa-bbbb-cccc-dddd',
        submittedAt: DateTime(2025),
      );
      expect(r.snippet, 'Short snippet');
      expect(r.body, 'Full long body');
    });

    test('defaults numeric counters to zero', () {
      final r = _build();
      expect(r.confirms, 0);
      expect(r.flags, 0);
      expect(r.views, 0);
      expect(r.commentCount, 0);
    });

    test('stores non-zero counters correctly', () {
      final r = _build(confirms: 412, flags: 3, views: 8421, commentCount: 8);
      expect(r.confirms, 412);
      expect(r.flags, 3);
      expect(r.views, 8421);
      expect(r.commentCount, 8);
    });
  });

  group('MyReport.photo getter', () {
    test('returns null when photos list is empty', () {
      expect(_build(photos: []).photo, isNull);
    });

    test('returns first photo URL when list is non-empty', () {
      final r = _build(
        photos: ['https://img.test/1.jpg', 'https://img.test/2.jpg'],
      );
      expect(r.photo, 'https://img.test/1.jpg');
    });
  });

  group('MyReport.tokenPreview getter', () {
    test('shows first 9 chars followed by ellipsis for 16-char token', () {
      final r = _build(token: 'abcd-1234-efgh-5678');
      expect(r.tokenPreview, 'abcd-1234 …');
    });

    test('returns full token when shorter than 9 chars', () {
      final r = _build(token: 'abc');
      expect(r.tokenPreview, 'abc');
    });
  });

  group('MyReport — status values', () {
    for (final s in ['pending', 'verified', 'disputed', 'deleted']) {
      test('accepts status "$s"', () {
        expect(_build(status: s).status, s);
      });
    }
  });

  group('MyReport — category values', () {
    for (final c in ['combat', 'aid', 'alert', 'displaced', 'infra', 'other']) {
      test('accepts category "$c"', () {
        expect(_build(category: c).category, c);
      });
    }
  });

  group('MyReport — optional discussion preview', () {
    test('preview fields are null by default', () {
      final r = _build();
      expect(r.previewCommentToken, isNull);
      expect(r.previewCommentContent, isNull);
      expect(r.previewCommentAt, isNull);
    });

    test('stores preview fields when provided', () {
      final r = MyReport(
        id: 'r',
        title: 't',
        body: 'b',
        category: 'aid',
        location: 'L',
        status: 'verified',
        token: 'aaaa-bbbb-cccc-dddd',
        submittedAt: DateTime(2025),
        previewCommentToken: 'token #h8m2',
        previewCommentContent: 'Confirmed power cut.',
        previewCommentAt: DateTime(2025, 3, 18, 3, 50),
      );
      expect(r.previewCommentToken, 'token #h8m2');
      expect(r.previewCommentContent, 'Confirmed power cut.');
      expect(r.previewCommentAt, DateTime(2025, 3, 18, 3, 50));
    });
  });
}
