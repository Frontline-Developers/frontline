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
    String? parentCommentId,
  });
  Future<void> upvote(String reportId, String commentId);
  Future<void> downvote(String reportId, String commentId);
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
    String? parentCommentId,
  }) async {
    final model = CommentModel(
      id: '',
      type: type,
      text: text.trim(),
      authorToken: authorToken,
      createdAt: DateTime.now(),
      upvotes: 0,
      parentCommentId: parentCommentId,
    );
    final batch = FirebaseFirestore.instance.batch();
    final commentRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('comments')
        .doc();
    batch.set(commentRef, model.toFirestore());
    // Only increment commentCount for top-level comments
    if (parentCommentId == null) {
      batch.update(
        FirebaseFirestore.instance.collection('reports').doc(reportId),
        {'commentCount': FieldValue.increment(1)},
      );
    }
    await batch.commit();
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
    final downvoterRef = commentRef.collection('downvoters').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final upSnap = await tx.get(upvoterRef);
      final downSnap = await tx.get(downvoterRef);
      final hasUpvoted = upSnap.exists;
      final hasDownvoted = downSnap.exists;

      if (hasUpvoted) {
        tx.delete(upvoterRef);
        tx.update(commentRef, {'upvotes': FieldValue.increment(-1)});
        if (hasDownvoted) {
          tx.delete(downvoterRef);
          tx.update(commentRef, {'downvotes': FieldValue.increment(-1)});
        }
        return;
      }

      if (hasDownvoted) {
        tx.delete(downvoterRef);
        tx.update(commentRef, {'downvotes': FieldValue.increment(-1)});
      }

      tx.set(upvoterRef, {'at': FieldValue.serverTimestamp()});
      tx.update(commentRef, {'upvotes': FieldValue.increment(1)});
    });
  }

  @override
  Future<void> downvote(String reportId, String commentId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final commentRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('comments')
        .doc(commentId);
    final upvoterRef = commentRef.collection('upvoters').doc(uid);
    final downvoterRef = commentRef.collection('downvoters').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final upSnap = await tx.get(upvoterRef);
      final downSnap = await tx.get(downvoterRef);
      final hasUpvoted = upSnap.exists;
      final hasDownvoted = downSnap.exists;

      if (hasDownvoted) {
        tx.delete(downvoterRef);
        tx.update(commentRef, {'downvotes': FieldValue.increment(-1)});
        if (hasUpvoted) {
          tx.delete(upvoterRef);
          tx.update(commentRef, {'upvotes': FieldValue.increment(-1)});
        }
        return;
      }

      if (hasUpvoted) {
        tx.delete(upvoterRef);
        tx.update(commentRef, {'upvotes': FieldValue.increment(-1)});
      }

      tx.set(downvoterRef, {'at': FieldValue.serverTimestamp()});
      tx.update(commentRef, {'downvotes': FieldValue.increment(1)});
    });
  }
}
