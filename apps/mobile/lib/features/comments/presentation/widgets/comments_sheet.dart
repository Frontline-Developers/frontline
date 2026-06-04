import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/comments_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _C {
  static const bg = Colors.white;
  static const surface = Color(0xFFF8F9FA);
  static const navy = Color(0xFF1E3A8A);
  static const ink = Color(0xFF212529);
  static const inkSub = Color(0xFF495057);
  static const inkMuted = Color(0xFF868E96);
  static const hairline = Color(0xFFE9ECEF);
  static const verified = Color(0xFF1F7A3F);
  static const verifiedBg = Color(0xFFECFDF5);
  static const disputed = Color(0xFFB42318);
  static const disputedBg = Color(0xFFFEE2E2);
  static const context_ = Color(0xFF1D4ED8);
  static const contextBg = Color(0xFFEFF6FF);
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
    return uid.length >= 6 ? 'token #${uid.substring(uid.length - 4)}' : 'you';
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
        color: _C.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
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
                          color: _C.inkMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _C.ink,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _C.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.hairline),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: _C.inkMuted,
                    ),
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

          const Divider(height: 1, color: _C.hairline),

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
                        style: TextStyle(color: _C.inkMuted, fontSize: 13),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _CommentCard(
                    comment: items[i],
                    myToken: _myToken,
                    onUpvote: () => ref
                        .read(commentsDatasourceProvider)
                        .upvote(widget.reportId, items[i].id),
                  ),
                );
              },
            ),
          ),

          // Composer
          _Composer(
            controller: _textCtrl,
            type: _draftType,
            sending: _sending,
            myToken: _myToken,
            onTypeChanged: (t) => setState(() => _draftType = t),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Stats + sort ──────────────────────────────────────────────────────────────

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
    final ctx = all.where((c) => c.type == CommentType.context).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.hairline),
            ),
            child: Row(
              children: [
                _StatItem(
                  icon: Icons.check_circle,
                  color: _C.verified,
                  count: confirms,
                  label: 'confirms',
                ),
                _VertDivider(),
                _StatItem(
                  icon: Icons.error_outline,
                  color: _C.disputed,
                  count: disputes,
                  label: 'disputes',
                ),
                _VertDivider(),
                _StatItem(
                  icon: Icons.info_outline,
                  color: _C.context_,
                  count: ctx,
                  label: 'context',
                ),
                const Spacer(),
                Text(
                  '${all.length} total',
                  style: const TextStyle(fontSize: 12, color: _C.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Sort tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in CommentSort.values) ...[
                  _SortTab(
                    label: s.label,
                    selected: sort == s,
                    onTap: () => onSort(s),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;
  const _StatItem({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: _C.inkMuted)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      color: _C.hairline,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}

class _SortTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _C.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _C.ink : _C.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : _C.inkMuted,
          ),
        ),
      ),
    );
  }
}

// ── Comment card ──────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final String myToken;
  final VoidCallback onUpvote;
  const _CommentCard({
    required this.comment,
    required this.myToken,
    required this.onUpvote,
  });

  @override
  Widget build(BuildContext context) {
    final token = comment.authorToken;
    final initials = token
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(
          0,
          token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length.clamp(0, 2),
        )
        .toUpperCase();

    final (
      borderColor,
      badgeBg,
      badgeFg,
      badgeLabel,
      badgeIcon,
    ) = switch (comment.type) {
      CommentType.confirm => (
        _C.verified,
        _C.verifiedBg,
        _C.verified,
        'CONFIRMS',
        Icons.check_circle_outline,
      ),
      CommentType.dispute => (
        _C.disputed,
        _C.disputedBg,
        _C.disputed,
        'DISPUTES',
        Icons.error_outline,
      ),
      CommentType.context => (
        _C.context_,
        _C.contextBg,
        _C.context_,
        'CONTEXT',
        Icons.info_outline,
      ),
    };

    final avatarColor = switch (comment.type) {
      CommentType.confirm => _C.verifiedBg,
      CommentType.dispute => _C.disputedBg,
      CommentType.context => _C.contextBg,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color bar
            Container(width: 3, color: borderColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: avatarColor,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: borderColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                token,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _C.ink,
                                ),
                              ),
                              Text(
                                _timeAgo(comment.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _C.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(5),
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
                                  fontWeight: FontWeight.w800,
                                  color: badgeFg,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    // Body
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _C.ink,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Actions row
                    Row(
                      children: [
                        // Upvote
                        GestureDetector(
                          onTap: onUpvote,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _C.hairline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_upward,
                                  size: 12,
                                  color: _C.inkMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.upvotes}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _C.inkSub,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_downward,
                                  size: 12,
                                  color: _C.inkMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Reply
                        GestureDetector(
                          onTap: () {},
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.reply, size: 14, color: _C.inkMuted),
                              SizedBox(width: 3),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _C.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Flag
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: _C.hairline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Composer ──────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final CommentType type;
  final bool sending;
  final String myToken;
  final void Function(CommentType) onTypeChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.type,
    required this.sending,
    required this.myToken,
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: _C.bg,
        border: Border(top: BorderSide(color: _C.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // YOU chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.hairline),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _C.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Input
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
                        color: _C.inkMuted,
                        fontSize: 13.5,
                      ),
                      filled: true,
                      fillColor: _C.surface,
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
              // Send button
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (ctx, val, child) {
                  final hasText = val.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: hasText && !sending ? onSend : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasText ? _C.navy : _C.surface,
                        border: Border.all(color: _C.hairline),
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
                              color: hasText ? Colors.white : _C.inkMuted,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Type chips
          Row(
            children: [
              _TypeChip(
                label: 'Mark as confirm',
                icon: Icons.check_box_outlined,
                color: _C.verified,
                selected: type == CommentType.confirm,
                onTap: () => onTypeChanged(CommentType.confirm),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Mark as dispute',
                icon: Icons.warning_amber_outlined,
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : _C.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : _C.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : _C.inkMuted,
                ),
              ),
            ],
          ),
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
