import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/data/datasources/vote_datasource.dart';

export '../../features/feed/data/datasources/vote_datasource.dart' show VoteCounts;

final voteDatasourceProvider = Provider<VoteDatasource>(
  (_) => VoteDatasourceImpl(),
);

// Reads the current user's vote ('confirm' | 'dispute' | null) for a report.
final voteProvider = FutureProvider.family<String?, String>((ref, reportId) {
  return ref.watch(voteDatasourceProvider).getUserVote(reportId);
});

// Streams live confirmCount / disputeCount for a single report document.
final voteCountsProvider = StreamProvider.family<VoteCounts, String>(
  (ref, reportId) =>
      ref.watch(voteDatasourceProvider).watchVoteCounts(reportId),
);
