import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class VoteDatasource {
  Future<String?> getUserVote(String reportId);
  Future<void> castVote(
    String reportId,
    String? type,
  ); // 'confirm'|'dispute'|null
}

class VoteDatasourceImpl implements VoteDatasource {
  @override
  Future<String?> getUserVote(String reportId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('votes')
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    return snap.data()?['type'] as String?;
  }

  @override
  Future<void> castVote(String reportId, String? type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final reportRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId);
    final voteRef = reportRef.collection('votes').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      String? oldType;
      if (voteSnap.exists) {
        oldType = voteSnap.data()?['type'] as String?;
      }

      if (oldType == type) {
        // Toggle off — remove vote
        tx.delete(voteRef);
        if (oldType == 'confirm') {
          tx.update(reportRef, {'confirmCount': FieldValue.increment(-1)});
        } else if (oldType == 'dispute') {
          tx.update(reportRef, {
            'disputeCount': FieldValue.increment(-1),
            'isDisputed': false,
          });
        }
        return;
      }

      // Remove old vote counts first
      if (oldType == 'confirm') {
        tx.update(reportRef, {'confirmCount': FieldValue.increment(-1)});
      } else if (oldType == 'dispute') {
        tx.update(reportRef, {
          'disputeCount': FieldValue.increment(-1),
          'isDisputed': false,
        });
      }

      if (type == null) {
        tx.delete(voteRef);
        return;
      }

      // Add new vote
      tx.set(voteRef, {
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (type == 'confirm') {
        tx.update(reportRef, {'confirmCount': FieldValue.increment(1)});
      } else if (type == 'dispute') {
        tx.update(reportRef, {
          'disputeCount': FieldValue.increment(1),
          'isDisputed': true,
        });
      }
    });
  }
}
