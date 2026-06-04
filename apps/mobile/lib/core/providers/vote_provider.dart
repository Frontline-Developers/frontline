import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/data/datasources/vote_datasource.dart';

final voteDatasourceProvider = Provider<VoteDatasource>(
  (_) => VoteDatasourceImpl(),
);

// Reads the current user's vote ('confirm' | 'dispute' | null) for a report.
final voteProvider = FutureProvider.family<String?, String>((ref, reportId) {
  return ref.watch(voteDatasourceProvider).getUserVote(reportId);
});

typedef VoteCounts = ({int confirm, int dispute});

// Streams live confirmCount / disputeCount for a single report document.
final voteCountsProvider = StreamProvider.family<VoteCounts, String>(
  (ref, reportId) => FirebaseFirestore.instance
      .collection('reports')
      .doc(reportId)
      .snapshots()
      .map(
        (snap) => (
          confirm: (snap.data()?['confirmCount'] as int?) ?? 0,
          dispute: (snap.data()?['disputeCount'] as int?) ?? 0,
        ),
      ),
);
