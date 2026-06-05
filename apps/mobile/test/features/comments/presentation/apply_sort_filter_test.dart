import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/comments/presentation/providers/comments_provider.dart';

Comment _make({
  required String id,
  required CommentType type,
  required int upvotes,
  int downvotes = 0,
  DateTime? createdAt,
}) => Comment(
  id: id,
  type: type,
  text: 'text $id',
  authorToken: 'tok',
  createdAt: createdAt ?? DateTime(2026, 6, 4, 10),
  upvotes: upvotes,
  downvotes: downvotes,
);

void main() {
  final older = DateTime(2026, 6, 4, 8);
  final newer = DateTime(2026, 6, 4, 12);

  final confirm1 = _make(
    id: 'c1',
    type: CommentType.confirm,
    upvotes: 10,
    createdAt: newer,
  );
  final confirm2 = _make(
    id: 'c2',
    type: CommentType.confirm,
    upvotes: 3,
    createdAt: older,
  );
  final dispute1 = _make(
    id: 'd1',
    type: CommentType.dispute,
    upvotes: 7,
    createdAt: older,
  );
  final context1 = _make(
    id: 'x1',
    type: CommentType.context,
    upvotes: 1,
    createdAt: newer,
  );

  final all = [confirm1, confirm2, dispute1, context1];

  group('applySortFilter — top', () {
    test('sorts by net score (upvotes - downvotes) descending', () {
      final result = applySortFilter(all, CommentSort.top);
      expect(result.map((c) => c.upvotes - c.downvotes).toList(), [
        10,
        7,
        3,
        1,
      ]);
    });

    test('preserves all items', () {
      final result = applySortFilter(all, CommentSort.top);
      expect(result.length, 4);
    });

    test('downvotes reduce net score and affect ordering', () {
      final highUpLowNet = _make(
        id: 'x',
        type: CommentType.context,
        upvotes: 10,
        downvotes: 8,
      ); // net 2
      final lowUpHighNet = _make(
        id: 'y',
        type: CommentType.context,
        upvotes: 3,
        downvotes: 0,
      ); // net 3
      final result = applySortFilter([
        highUpLowNet,
        lowUpHighNet,
      ], CommentSort.top);
      expect(result.first.id, 'y');
    });
  });

  group('applySortFilter — recent', () {
    test('sorts by createdAt descending (newest first)', () {
      final result = applySortFilter(all, CommentSort.recent);
      expect(result.first.createdAt, newer);
      expect(result.last.createdAt, older);
    });

    test('preserves all items', () {
      final result = applySortFilter(all, CommentSort.recent);
      expect(result.length, 4);
    });
  });

  group('applySortFilter — confirm', () {
    test('returns only confirm-type comments', () {
      final result = applySortFilter(all, CommentSort.confirm);
      expect(result.every((c) => c.type == CommentType.confirm), isTrue);
    });

    test('excludes disputes and context', () {
      final result = applySortFilter(all, CommentSort.confirm);
      expect(result.length, 2);
    });
  });

  group('applySortFilter — dispute', () {
    test('returns only dispute-type comments', () {
      final result = applySortFilter(all, CommentSort.dispute);
      expect(result.every((c) => c.type == CommentType.dispute), isTrue);
    });

    test('returns correct count', () {
      final result = applySortFilter(all, CommentSort.dispute);
      expect(result.length, 1);
    });
  });

  group('applySortFilter — edge cases', () {
    test('returns empty list when input is empty', () {
      expect(applySortFilter([], CommentSort.top), isEmpty);
      expect(applySortFilter([], CommentSort.confirm), isEmpty);
    });

    test('does not mutate the original list', () {
      final original = List<Comment>.from(all);
      applySortFilter(all, CommentSort.top);
      expect(all, original);
    });
  });
}
