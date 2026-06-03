import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final commentRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('comments')
        .doc(commentId);
    final upvoterRef = commentRef.collection('upvoters').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(upvoterRef);
      if (snap.exists) {
        // Toggle off — remove upvote
        tx.delete(upvoterRef);
        tx.update(commentRef, {'upvotes': FieldValue.increment(-1)});
      } else {
        // Toggle on — add upvote
        tx.set(upvoterRef, {'at': FieldValue.serverTimestamp()});
        tx.update(commentRef, {'upvotes': FieldValue.increment(1)});
      }
    });
  }
}
