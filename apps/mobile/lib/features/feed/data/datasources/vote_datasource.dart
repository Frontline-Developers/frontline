import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef VoteCounts = ({int confirm, int dispute});

abstract class VoteDatasource {
  Future<String?> getUserVote(String reportId);
  Future<void> castVote(String reportId, String? type);
  Stream<VoteCounts> watchVoteCounts(String reportId);
}

class VoteDatasourceImpl implements VoteDatasource {
  static String _randomToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<String?> getUserVote(String reportId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .collection('interactions')
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
    final voteRef = reportRef.collection('interactions').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final reportSnap = await tx.get(reportRef);

      String? oldType;
      if (voteSnap.exists) {
        oldType = voteSnap.data()?['type'] as String?;
      }

      // Read actual counts so isDisputed stays consistent with reality.
      int confirmCount = (reportSnap.data()?['confirmCount'] as int?) ?? 0;
      int disputeCount = (reportSnap.data()?['disputeCount'] as int?) ?? 0;

      // Remove effect of the user's previous vote.
      if (oldType == 'confirm') confirmCount--;
      if (oldType == 'dispute') disputeCount--;

      if (oldType == type) {
        // Toggle off — remove vote, add no new one.
        tx.delete(voteRef);
      } else {
        // Apply new vote.
        if (type == 'confirm') confirmCount++;
        if (type == 'dispute') disputeCount++;

        if (type == null) {
          tx.delete(voteRef);
        } else {
          tx.set(voteRef, {
            'type': type,
            'token': _randomToken(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      tx.update(reportRef, {
        'confirmCount': max(0, confirmCount),
        'disputeCount': max(0, disputeCount),
        'isDisputed': max(0, disputeCount) > 0,
      });
    });
  }

  @override
  Stream<VoteCounts> watchVoteCounts(String reportId) =>
      FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .snapshots()
          .map(
            (snap) => (
              confirm: (snap.data()?['confirmCount'] as int?) ?? 0,
              dispute: (snap.data()?['disputeCount'] as int?) ?? 0,
            ),
          );
}
