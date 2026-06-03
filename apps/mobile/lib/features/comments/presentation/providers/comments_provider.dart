import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/comments_datasource.dart';
import '../../domain/entities/comment.dart';

export '../../domain/entities/comment.dart';

enum CommentSort { top, recent, confirm, dispute }

final commentsDatasourceProvider = Provider<CommentsDatasource>(
  (_) => CommentsDatasourceImpl(),
);

final commentsStreamProvider = StreamProvider.family<List<Comment>, String>((
  ref,
  reportId,
) {
  return ref.read(commentsDatasourceProvider).watchComments(reportId);
});

List<Comment> applySortFilter(List<Comment> all, CommentSort sort) {
  return switch (sort) {
    CommentSort.top => ([
      ...all,
    ]..sort((a, b) => b.upvotes.compareTo(a.upvotes))),
    CommentSort.recent => ([
      ...all,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
    CommentSort.confirm =>
      all.where((c) => c.type == CommentType.confirm).toList(),
    CommentSort.dispute =>
      all.where((c) => c.type == CommentType.dispute).toList(),
  };
}
