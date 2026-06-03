import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/comments_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _C {
  static const surface = Color(0xFFF8F9FA);
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMMUNITY DISCUSSION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _C.inkTertiary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _C.ink,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: _C.inkSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
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
              onSort: (s) => setState(() => _sort = s),
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
              data: (all) {
                final items = applySortFilter(all, _sort);
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
                  itemCount: items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      return const _AnonNote();
                    }
                    return _CommentItem(
                      comment: items[i],
                      myToken: _myToken,
                      onUpvote: () => ref
                          .read(commentsDatasourceProvider)
                          .upvote(widget.reportId, items[i].id),
                    );
                  },
                );
              },
            ),
          ),
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
  const _StatsAndSort({
    required this.all,
    required this.sort,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final confirms = all.where((c) => c.type == CommentType.confirm).length;
    final disputes = all.where((c) => c.type == CommentType.dispute).length;
    final context_ = all.where((c) => c.type == CommentType.context).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.hairlineSoft),
            ),
            child: Row(
              children: [
                _Stat(
                  icon: Icons.check_circle,
                  color: _C.verified,
                  value: confirms,
                  label: 'confirms',
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: _C.hairline,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                _Stat(
                  icon: Icons.warning_outlined,
                  color: _C.disputed,
                  value: disputes,
                  label: 'disputes',
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: _C.hairline,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                _Stat(
                  icon: Icons.info_outline,
                  color: _C.inkSecondary,
                  value: context_,
                  label: 'context',
                ),
                const Spacer(),
                Text(
                  '${all.length} total',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.inkTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                          horizontal: 12,
                          vertical: 6,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: _C.inkTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Comment item ──────────────────────────────────────────────────────────────

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final String myToken;
  final VoidCallback onUpvote;
  const _CommentItem({
    required this.comment,
    required this.myToken,
    required this.onUpvote,
  });

  @override
  Widget build(BuildContext context) {
    final (borderColor, badgeBg, badgeFg, badgeLabel) = switch (comment.type) {
      CommentType.confirm => (
        _C.verified,
        _C.verifiedSoft,
        _C.verified,
        'Confirms',
      ),
      CommentType.dispute => (
        _C.disputed,
        _C.disputedSoft,
        _C.disputed,
        'Disputes',
      ),
      CommentType.context => (
        _C.inkTertiary,
        _C.raised,
        _C.inkSecondary,
        'Context',
      ),
    };

    final isMe = comment.authorToken == myToken;
    final initials = comment.authorToken.substring(0, 2).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
          top: BorderSide(color: _C.hairlineSoft),
          right: BorderSide(color: _C.hairlineSoft),
          bottom: BorderSide(color: _C.hairlineSoft),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.raised,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: _C.inkSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe
                          ? '${comment.authorToken} (you)'
                          : comment.authorToken,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: _C.inkSecondary,
                      ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.text,
            style: const TextStyle(fontSize: 13.5, color: _C.ink, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: onUpvote,
                child: Container(
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
                      const Icon(
                        Icons.arrow_upward,
                        size: 12,
                        color: _C.inkSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.upvotes}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _C.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: _C.inkTertiary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Comments are anonymous — each commenter gets a random token. Replying does not link you to the original commenter.',
              style: TextStyle(
                fontSize: 11,
                color: _C.inkTertiary,
                height: 1.5,
              ),
            ),
          ),
        ],
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
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.raised,
                ),
                child: const Center(
                  child: Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _C.inkSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
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
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
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
