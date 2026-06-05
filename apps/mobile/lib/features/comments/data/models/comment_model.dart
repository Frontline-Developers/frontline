import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/comment.dart';

class CommentModel {
  final String id;
  final CommentType type;
  final String text;
  final String authorToken;
  final DateTime createdAt;
  final int upvotes;

  const CommentModel({
    required this.id,
    required this.type,
    required this.text,
    required this.authorToken,
    required this.createdAt,
    required this.upvotes,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawType = data['type'] as String? ?? 'context';
    final type = switch (rawType) {
      'confirm' => CommentType.confirm,
      'dispute' => CommentType.dispute,
      _ => CommentType.context,
    };
    final ts = data['createdAt'];
    return CommentModel(
      id: doc.id,
      type: type,
      text: data['text'] as String? ?? '',
      authorToken: data['authorToken'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      upvotes: (data['upvotes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'type': type.name,
    'text': text,
    'authorToken': authorToken,
    'createdAt': FieldValue.serverTimestamp(),
    'upvotes': 0,
  };

  Comment toEntity() => Comment(
    id: id,
    type: type,
    text: text,
    authorToken: authorToken,
    createdAt: createdAt,
    upvotes: upvotes,
  );
}
