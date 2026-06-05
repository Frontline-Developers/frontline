import 'package:flutter_test/flutter_test.dart';
import 'package:frontline/features/comments/domain/entities/comment.dart';

void main() {
  final now = DateTime(2026, 6, 4, 10, 0);

  group('Comment', () {
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

  group('downvotes field', () {
    test('defaults to 0 when not provided', () {
      final c = Comment(
        id: 'c-4',
        type: CommentType.context,
        text: 'test',
        authorToken: 'tok',
        createdAt: now,
        upvotes: 3,
      );
      expect(c.downvotes, 0);
    });

    test('stores non-zero downvotes', () {
      final c = Comment(
        id: 'c-5',
        type: CommentType.dispute,
        text: 'test',
        authorToken: 'tok',
        createdAt: now,
        upvotes: 5,
        downvotes: 2,
      );
      expect(c.downvotes, 2);
    });
  });

  group('parentCommentId field', () {
    test('defaults to null for top-level comments', () {
      final c = Comment(
        id: 'c-6',
        type: CommentType.context,
        text: 'test',
        authorToken: 'tok',
        createdAt: now,
        upvotes: 0,
      );
      expect(c.parentCommentId, isNull);
    });

    test('stores parent id for replies', () {
      final c = Comment(
        id: 'c-7',
        type: CommentType.context,
        text: 'reply',
        authorToken: 'tok',
        createdAt: now,
        upvotes: 0,
        parentCommentId: 'c-1',
      );
      expect(c.parentCommentId, 'c-1');
    });
  });

  group('replies field', () {
    test('defaults to empty list', () {
      final c = Comment(
        id: 'c-8',
        type: CommentType.context,
        text: 'test',
        authorToken: 'tok',
        createdAt: now,
        upvotes: 0,
      );
      expect(c.replies, isEmpty);
    });

    test('stores nested replies', () {
      final reply = Comment(
        id: 'c-9',
        type: CommentType.context,
        text: 'nested',
        authorToken: 'tok2',
        createdAt: now,
        upvotes: 0,
        parentCommentId: 'c-8',
      );
      final parent = Comment(
        id: 'c-8',
        type: CommentType.confirm,
        text: 'parent',
        authorToken: 'tok',
        createdAt: now,
        upvotes: 1,
        replies: [reply],
      );
      expect(parent.replies.length, 1);
      expect(parent.replies.first.id, 'c-9');
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
