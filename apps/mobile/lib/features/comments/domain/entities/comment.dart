enum CommentType { confirm, dispute, context }

class Comment {
  final String id;
  final CommentType type;
  final String text;
  final String authorToken;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;
  final String? parentCommentId;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.type,
    required this.text,
    required this.authorToken,
    required this.createdAt,
    required this.upvotes,
    this.downvotes = 0,
    this.parentCommentId,
    this.replies = const [],
  });
}
