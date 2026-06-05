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
  return ref.watch(commentsDatasourceProvider).watchComments(reportId);
});

List<Comment> buildCommentTree(List<Comment> flat) {
  final childrenOf = <String, List<Comment>>{};
  for (final c in flat) {
    if (c.parentCommentId != null) {
      childrenOf.putIfAbsent(c.parentCommentId!, () => []).add(c);
    }
  }

  Comment withReplies(Comment c) {
    final kids = childrenOf[c.id] ?? [];
    return Comment(
      id: c.id,
      type: c.type,
      text: c.text,
      authorToken: c.authorToken,
      createdAt: c.createdAt,
      upvotes: c.upvotes,
      downvotes: c.downvotes,
      parentCommentId: c.parentCommentId,
      replies: kids.map(withReplies).toList(),
    );
  }

  return flat.where((c) => c.parentCommentId == null).map(withReplies).toList();
}

List<Comment> applySortFilter(List<Comment> all, CommentSort sort) {
  return switch (sort) {
    CommentSort.top =>
      ([...all]..sort(
        (a, b) => (b.upvotes - b.downvotes).compareTo(a.upvotes - a.downvotes),
      )),
    CommentSort.recent => ([
      ...all,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
    CommentSort.confirm =>
      all.where((c) => c.type == CommentType.confirm).toList(),
    CommentSort.dispute =>
      all.where((c) => c.type == CommentType.dispute).toList(),
  };
}
