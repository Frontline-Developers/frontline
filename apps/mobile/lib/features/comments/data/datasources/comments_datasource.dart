import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/comment.dart';
import '../models/comment_model.dart';

abstract class CommentsDatasource {
  Stream<List<Comment>> watchComments(String reportId);
  Future<void> addComment({
    required String reportId,
    required String text,
    required CommentType type,
    required String authorToken,
  });
  Future<void> upvote(String reportId, String commentId);
}

class CommentsDatasourceImpl implements CommentsDatasource {
  @override
  Stream<List<Comment>> watchComments(String reportId) {
    return FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(CommentModel.fromFirestore)
              .map((m) => m.toEntity())
              .toList(),
        );
  }

  @override
  Future<void> addComment({
    required String reportId,
    required String text,
    required CommentType type,
    required String authorToken,
  }) async {
    final model = CommentModel(
      id: '',
      type: type,
      text: text.trim(),
      authorToken: authorToken,
      createdAt: DateTime.now(),
      upvotes: 0,
    );
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('comments')
        .add(model.toFirestore());
  }

  @override
  Future<void> upvote(String reportId, String commentId) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('comments')
        .doc(commentId)
        .update({'upvotes': FieldValue.increment(1)});
  }
}
