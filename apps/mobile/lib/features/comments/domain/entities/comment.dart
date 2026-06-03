enum CommentType { confirm, dispute, context }

class Comment {
  final String id;
  final CommentType type;
  final String text;
  final String authorToken;
  final DateTime createdAt;
  final int upvotes;

  const Comment({
    required this.id,
    required this.type,
    required this.text,
    required this.authorToken,
    required this.createdAt,
    required this.upvotes,
  });
}
