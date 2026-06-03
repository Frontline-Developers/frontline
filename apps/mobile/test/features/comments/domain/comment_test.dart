import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/comments/domain/entities/comment.dart';

void main() {
  group('Comment', () {
    final now = DateTime(2026, 6, 4, 10, 0);

    final comment = Comment(
      id: 'c-1',
      type: CommentType.confirm,
      text: 'I was there, this is accurate.',
      authorToken: 'abc123',
      createdAt: now,
      upvotes: 5,
    );

    test('stores all fields', () {
      expect(comment.id, 'c-1');
      expect(comment.type, CommentType.confirm);
      expect(comment.text, 'I was there, this is accurate.');
      expect(comment.authorToken, 'abc123');
      expect(comment.upvotes, 5);
    });

    test('createdAt is stored', () {
      expect(comment.createdAt, now);
    });

    test('dispute type comment', () {
      final dispute = Comment(
        id: 'c-2',
        type: CommentType.dispute,
        text: 'No activity seen in this area.',
        authorToken: 'xyz999',
        createdAt: now,
        upvotes: 0,
      );
      expect(dispute.type, CommentType.dispute);
    });

    test('context type comment', () {
      final context = Comment(
        id: 'c-3',
        type: CommentType.context,
        text: 'This is near the checkpoint.',
        authorToken: 'def456',
        createdAt: now,
        upvotes: 2,
      );
      expect(context.type, CommentType.context);
    });
  });

  group('CommentType enum', () {
    test('has confirm, dispute, context values', () {
      expect(
        CommentType.values,
        containsAll([
          CommentType.confirm,
          CommentType.dispute,
          CommentType.context,
        ]),
      );
    });
  });
}
