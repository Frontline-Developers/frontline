import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/comments/presentation/providers/comments_provider.dart';

Comment _c({required String id, String? parentId, int upvotes = 0}) => Comment(
  id: id,
  type: CommentType.context,
  text: 'text',
  authorToken: 'tok',
  createdAt: DateTime(2026, 6, 4),
  upvotes: upvotes,
  parentCommentId: parentId,
);

void main() {
  group('buildCommentTree', () {
    test('returns empty list for empty input', () {
      expect(buildCommentTree([]), isEmpty);
    });

    test('flat list with no parents → all top-level', () {
      final result = buildCommentTree([_c(id: 'a'), _c(id: 'b'), _c(id: 'c')]);
      expect(result.length, 3);
      expect(result.every((c) => c.replies.isEmpty), isTrue);
    });

    test('reply attaches to correct parent', () {
      final parent = _c(id: 'p');
      final child = _c(id: 'r1', parentId: 'p');
      final result = buildCommentTree([parent, child]);
      expect(result.length, 1);
      expect(result.first.id, 'p');
      expect(result.first.replies.length, 1);
      expect(result.first.replies.first.id, 'r1');
    });

    test('reply of reply attaches to correct grandparent chain', () {
      final grandparent = _c(id: 'gp');
      final parent = _c(id: 'p', parentId: 'gp');
      final child = _c(id: 'c', parentId: 'p');
      final result = buildCommentTree([grandparent, parent, child]);
      expect(result.length, 1);
      final gp = result.first;
      expect(gp.replies.length, 1);
      final p = gp.replies.first;
      expect(p.replies.length, 1);
      expect(p.replies.first.id, 'c');
    });

    test('multiple replies attach to correct parents', () {
      final p1 = _c(id: 'p1');
      final p2 = _c(id: 'p2');
      final r1a = _c(id: 'r1a', parentId: 'p1');
      final r1b = _c(id: 'r1b', parentId: 'p1');
      final r2a = _c(id: 'r2a', parentId: 'p2');
      final result = buildCommentTree([p1, p2, r1a, r1b, r2a]);
      expect(result.length, 2);
      final tree1 = result.firstWhere((c) => c.id == 'p1');
      final tree2 = result.firstWhere((c) => c.id == 'p2');
      expect(tree1.replies.length, 2);
      expect(tree2.replies.length, 1);
    });

    test('orphan reply (unknown parentCommentId) is silently dropped', () {
      final orphan = _c(id: 'o', parentId: 'nonexistent');
      final result = buildCommentTree([orphan]);
      expect(result, isEmpty);
    });

    test('top-level comments do not appear in any replies list', () {
      final a = _c(id: 'a');
      final b = _c(id: 'b');
      final result = buildCommentTree([a, b]);
      final allReplies = result.expand((c) => c.replies).toList();
      expect(allReplies, isEmpty);
    });
  });
}
