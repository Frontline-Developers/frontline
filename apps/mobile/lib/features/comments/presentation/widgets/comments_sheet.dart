import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/comments_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _C {
  static const card = Colors.white;
  static const navy = Color(0xFF1E3A8A);
  static const ink = Color(0xFF212529);
  static const inkSecondary = Color(0xFF495057);
  static const inkTertiary = Color(0xFF868E96);
  static const hairline = Color(0xFFDEE2E6);
  static const hairlineSoft = Color(0xFFE9ECEF);
  static const raised = Color(0xFFF1F3F5);
  static const verified = Color(0xFF1F7A3F);
  static const verifiedSoft = Color(0xFFECFDF5);
  static const disputed = Color(0xFFB42318);
  static const disputedSoft = Color(0xFFFEE2E2);
}

// ── Entry point ───────────────────────────────────────────────────────────────

void showCommentsSheet(
  BuildContext context, {
  required String reportId,
  required String title,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(reportId: reportId, title: title),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class CommentsSheet extends ConsumerStatefulWidget {
  final String reportId;
  final String title;
  const CommentsSheet({super.key, required this.reportId, required this.title});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  CommentSort _sort = CommentSort.top;
  CommentType _draftType = CommentType.context;
  final _textCtrl = TextEditingController();
  bool _sending = false;
  final _commentOrder = <String>[];
  bool _shouldResort = true;

  String get _myToken {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return uid.length >= 6 ? uid.substring(uid.length - 6) : uid;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(commentsDatasourceProvider)
          .addComment(
            reportId: widget.reportId,
            text: text,
            type: _draftType,
            authorToken: _myToken,
          );
      _textCtrl.clear();
      _shouldResort = true;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _markResortNeeded() {
    _shouldResort = true;
  }

  void _refreshOrder() {
    setState(() {
      _shouldResort = true;
    });
  }

  List<Comment> _stableSortedComments(List<Comment> tree) {
    final visible = applySortFilter(tree, _sort);
    if (_shouldResort || _commentOrder.isEmpty) {
      _commentOrder
        ..clear()
        ..addAll(visible.map((c) => c.id));
      _shouldResort = false;
      return visible;
    }

    final byId = {for (final comment in visible) comment.id: comment};
    final ordered = <Comment>[];
    for (final id in _commentOrder) {
      final comment = byId.remove(id);
      if (comment != null) ordered.add(comment);
    }
    ordered.addAll(byId.values);
    _commentOrder
      ..clear()
      ..addAll(ordered.map((c) => c.id));
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(commentsStreamProvider(widget.reportId));

    return Container(
      decoration: const BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _C.hairline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _C.ink,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: _C.inkSecondary),
                  ),
                ),
              ],
            ),
          ),
          // Stats + sort
          async.when(
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
            data: (all) => _StatsAndSort(
              all: all,
              sort: _sort,
              onSort: (s) => setState(() {
                _sort = s;
                _markResortNeeded();
              }),
              onRefresh: _refreshOrder,
            ),
          ),
          const Divider(height: 1, color: _C.hairlineSoft),
          // Comment list
          Flexible(
            child: async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _C.navy),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(color: _C.disputed, fontSize: 13),
                  ),
                ),
              ),
              data: (flat) {
                final tree = buildCommentTree(flat);
                final items = _stableSortedComments(tree);
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No comments yet.\nBe the first to add context.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _C.inkTertiary, fontSize: 13),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _CommentItem(
                    key: ValueKey(items[i].id),
                    comment: items[i],
                    myToken: _myToken,
                    reportId: widget.reportId,
                  ),
                );
              },
            ),
          ),
          const _AnonNote(),
          // Composer
          _Composer(
            controller: _textCtrl,
            type: _draftType,
            sending: _sending,
            onTypeChanged: (t) => setState(() => _draftType = t),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Stats + sort row ──────────────────────────────────────────────────────────

class _StatsAndSort extends StatelessWidget {
  final List<Comment> all;
  final CommentSort sort;
  final void Function(CommentSort) onSort;
  final VoidCallback onRefresh;
  const _StatsAndSort({
    required this.all,
    required this.sort,
    required this.onSort,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final confirms = all.where((c) => c.type == CommentType.confirm).length;
    final disputes = all.where((c) => c.type == CommentType.dispute).length;
    final context_ = all.where((c) => c.type == CommentType.context).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 13, color: _C.verified),
              const SizedBox(width: 4),
              Text(
                '$confirms',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.verified,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.warning_outlined, size: 13, color: _C.disputed),
              const SizedBox(width: 4),
              Text(
                '$disputes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.disputed,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.info_outline, size: 13, color: _C.inkTertiary),
              const SizedBox(width: 4),
              Text(
                '$context_',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.inkTertiary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRefresh,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.refresh, size: 14, color: _C.inkSecondary),
                ),
              ),
              Text(
                '${all.length} total',
                style: const TextStyle(fontSize: 11, color: _C.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in CommentSort.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onSort(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: sort == s ? _C.ink : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: sort == s ? _C.ink : _C.hairline,
                          ),
                        ),
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: sort == s ? Colors.white : _C.inkSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment item ──────────────────────────────────────────────────────────────

class _CommentItem extends ConsumerStatefulWidget {
  final Comment comment;
  final String myToken;
  final String reportId;
  final int depth;

  const _CommentItem({
    super.key,
    required this.comment,
    required this.myToken,
    required this.reportId,
    this.depth = 0,
  });

  @override
  ConsumerState<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<_CommentItem> {
  bool _replyOpen = false;
  bool _repliesVisible = true;
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _doUpvote() async {
    await ref
        .read(commentsDatasourceProvider)
        .upvote(widget.reportId, widget.comment.id);
  }

  Future<void> _doDownvote() async {
    await ref
        .read(commentsDatasourceProvider)
        .downvote(widget.reportId, widget.comment.id);
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(commentsDatasourceProvider)
          .addComment(
            reportId: widget.reportId,
            text: text,
            type: CommentType.context,
            authorToken: widget.myToken,
            parentCommentId: widget.comment.id,
          );
      _replyCtrl.clear();
      setState(() => _replyOpen = false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final isMe = comment.authorToken == widget.myToken;
    final token = comment.authorToken;
    final initials = (token.length >= 2 ? token.substring(0, 2) : token)
        .toUpperCase();
    final net = comment.upvotes - comment.downvotes;

    final (
      borderColor,
      badgeBg,
      badgeFg,
      badgeLabel,
      badgeIcon,
    ) = switch (comment.type) {
      CommentType.confirm => (
        _C.verified,
        _C.verifiedSoft,
        _C.verified,
        'CONFIRMS',
        Icons.check,
      ),
      CommentType.dispute => (
        _C.disputed,
        _C.disputedSoft,
        _C.disputed,
        'DISPUTES',
        Icons.warning_rounded,
      ),
      CommentType.context => (
        _C.inkTertiary,
        _C.raised,
        _C.inkSecondary,
        'CONTEXT',
        Icons.info_outline,
      ),
    };

    return Padding(
      padding: EdgeInsets.only(left: widget.depth > 0 ? 20.0 : 0.0, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card
          Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.hairlineSoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: borderColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: avatar | token + time | badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _C.raised,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: _C.inkSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMe
                                          ? '${comment.authorToken} (you)'
                                          : comment.authorToken,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                        color: _C.inkSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _timeAgo(comment.createdAt),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _C.inkTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Type badge (top-level only)
                              if (widget.depth == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(badgeIcon, size: 10, color: badgeFg),
                                      const SizedBox(width: 3),
                                      Text(
                                        badgeLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Body
                          Text(
                            comment.text,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: _C.ink,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Footer: vote pill | Reply | spacer | flag
                          Row(
                            children: [
                              // Vote pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _C.raised,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: _C.hairlineSoft),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _doUpvote,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.arrow_upward,
                                          size: 13,
                                          color: _C.inkSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$net',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        color: net > 0
                                            ? _C.verified
                                            : net < 0
                                            ? _C.disputed
                                            : _C.inkSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _doDownvote,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: 13,
                                          color: _C.inkSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reply button
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _replyOpen = !_replyOpen),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.reply,
                                        size: 13,
                                        color: _replyOpen
                                            ? _C.navy
                                            : _C.inkSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Reply',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: _replyOpen
                                              ? _C.navy
                                              : _C.inkSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Replies count toggle
                              if (comment.replies.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _repliesVisible = !_repliesVisible,
                                  ),
                                  child: Text(
                                    _repliesVisible
                                        ? '${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'} ▲'
                                        : '${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'} ▼',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _C.navy,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Flag
                              GestureDetector(
                                onTap: () {},
                                child: const Icon(
                                  Icons.flag_outlined,
                                  size: 15,
                                  color: _C.inkTertiary,
                                ),
                              ),
                            ],
                          ),
                          // Inline reply composer
                          if (_replyOpen) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _replyCtrl,
                                    minLines: 1,
                                    maxLines: 3,
                                    autofocus: true,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _C.ink,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Reply to ${comment.authorToken}…',
                                      hintStyle: const TextStyle(
                                        color: _C.inkTertiary,
                                        fontSize: 13,
                                      ),
                                      filled: true,
                                      fillColor: _C.raised,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _replyCtrl,
                                  builder: (ctx2, val, child2) {
                                    final hasText = val.text.trim().isNotEmpty;
                                    return GestureDetector(
                                      onTap: hasText && !_sending
                                          ? _sendReply
                                          : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: hasText ? _C.navy : _C.raised,
                                        ),
                                        child: _sending
                                            ? const Padding(
                                                padding: EdgeInsets.all(8),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.send,
                                                size: 14,
                                                color: hasText
                                                    ? Colors.white
                                                    : _C.inkTertiary,
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Recursive replies
          if (comment.replies.isNotEmpty && _repliesVisible)
            ...comment.replies.map(
              (r) => _CommentItem(
                key: ValueKey(r.id),
                comment: r,
                myToken: widget.myToken,
                reportId: widget.reportId,
                depth: widget.depth + 1,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Anon note ─────────────────────────────────────────────────────────────────

class _AnonNote extends StatelessWidget {
  const _AnonNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'Comments are anonymous — tokens don\'t identify you.',
        style: TextStyle(fontSize: 11, color: _C.inkTertiary),
      ),
    );
  }
}

// ── Composer ──────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final CommentType type;
  final bool sending;
  final void Function(CommentType) onTypeChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.type,
    required this.sending,
    required this.onTypeChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: _C.card,
        border: Border(top: BorderSide(color: _C.hairlineSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      onSend();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 13.5, color: _C.ink),
                    decoration: InputDecoration(
                      hintText: 'Add context, confirm, or dispute…',
                      hintStyle: const TextStyle(
                        color: _C.inkTertiary,
                        fontSize: 13.5,
                      ),
                      filled: true,
                      fillColor: _C.raised,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (ctx, val, child) {
                  final hasText = val.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: hasText && !sending ? onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasText ? const Color(0xFF1E3A8A) : _C.raised,
                      ),
                      child: sending
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              size: 16,
                              color: hasText ? Colors.white : _C.inkTertiary,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TypeChip(
                label: 'Mark as confirm',
                icon: Icons.check,
                color: _C.verified,
                selected: type == CommentType.confirm,
                onTap: () => onTypeChanged(CommentType.confirm),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Mark as dispute',
                icon: Icons.warning_outlined,
                color: _C.disputed,
                selected: type == CommentType.dispute,
                onTap: () => onTypeChanged(CommentType.dispute),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : _C.raised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : _C.hairlineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? color : _C.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

extension on CommentSort {
  String get label => switch (this) {
    CommentSort.top => 'Top',
    CommentSort.recent => 'New',
    CommentSort.confirm => 'Confirms',
    CommentSort.dispute => 'Disputes',
  };
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
