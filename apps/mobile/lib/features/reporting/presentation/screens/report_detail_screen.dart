import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../comments/presentation/providers/comments_provider.dart';
import '../../../comments/presentation/widgets/comments_sheet.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../../../feed/presentation/providers/vote_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _P {
  static const surface = AppColors.reportSurface;
  static const card = AppColors.reportSurfaceCard;
  static const raised = AppColors.reportSurfaceRaised;
  static const navy = AppColors.reportNavy;
  static const navySoft = AppColors.reportNavySoft;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const hairlineSoft = AppColors.reportHairlineSoft;
  static const citizen = Color(0xFFB54708);
  static const citizenSoft = Color(0xFFFEF3C7);
  static const verified = AppColors.reportVerified;
  static const disputed = AppColors.reportDisputed;
  static const disputedSoft = Color(0xFFFEE2E2);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportDetailScreen extends ConsumerStatefulWidget {
  final NewsItem item;
  const ReportDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  int _imageIndex = 0;
  bool _bookmarked = false;

  Future<void> _castVote(String type) async {
    final ds = ref.read(voteDatasourceProvider);
    await ds.castVote(widget.item.id, type);
    ref.invalidate(voteProvider(widget.item.id));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCitizen = item.source == NewsSource.citizen;

    final voteAsync = ref.watch(voteProvider(item.id));
    final userVote = voteAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (e, _) => null,
    );

    final commentsAsync = ref.watch(commentsStreamProvider(item.id));
    final comments = commentsAsync.when(
      data: (c) => c,
      loading: () => const <Comment>[],
      error: (e, _) => const <Comment>[],
    );

    return Scaffold(
      backgroundColor: _P.surface,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  item: item,
                  bookmarked: _bookmarked,
                  onBookmark: () => setState(() => _bookmarked = !_bookmarked),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroSection(
                          item: item,
                          imageIndex: _imageIndex,
                          onImageTap: (i) => setState(() => _imageIndex = i),
                        ),
                        _MetaRow(item: item),
                        _TitleBody(item: item),
                        if (!isCitizen && item.url != null)
                          _ReadArticleButton(url: item.url!),
                        if (isCitizen)
                          _VerificationPanel(
                            item: item,
                            userVote: userVote,
                            onConfirm: () => _castVote('confirm'),
                            onFlag: () => _castVote('dispute'),
                          ),
                        _CompareCTA(item: item),
                        _DiscussionSection(item: item, comments: comments),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionBar(
              isCitizen: isCitizen,
              onComment: () => showCommentsSheet(
                context,
                reportId: item.id,
                title: item.title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final NewsItem item;
  final bool bookmarked;
  final VoidCallback onBookmark;
  const _TopBar({
    required this.item,
    required this.bookmarked,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final isCitizen = item.source == NewsSource.citizen;
    final dotColor = isCitizen ? _P.citizen : _P.navy;
    final sourceLabel = isCitizen
        ? 'CITIZEN REPORT'
        : (item.sourceName ?? 'WIRE NEWS');

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      decoration: BoxDecoration(
        color: _P.card,
        border: Border(bottom: BorderSide(color: _P.hairlineSoft, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => context.pop(),
            color: _P.ink,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              sourceLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _P.inkSecondary,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 18),
            onPressed: () {},
            color: _P.inkSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
          ),
          if (isCitizen)
            IconButton(
              icon: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
              ),
              onPressed: onBookmark,
              color: bookmarked ? _P.navy : _P.inkSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            ),
        ],
      ),
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final NewsItem item;
  final int imageIndex;
  final void Function(int) onImageTap;
  const _HeroSection({
    required this.item,
    required this.imageIndex,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCitizen = item.source == NewsSource.citizen;
    final imageUrls = isCitizen
        ? item.mediaUrls
        : (item.imageUrl != null ? [item.imageUrl!] : <String>[]);
    final placeholderColor = isCitizen
        ? const Color(0xFF5C3317)
        : const Color(0xFF1A3A5C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrls.isNotEmpty
                  ? Image.network(
                      imageUrls[imageIndex.clamp(0, imageUrls.length - 1)],
                      fit: BoxFit.cover,
                      errorBuilder: (context, err, _) =>
                          Container(color: placeholderColor),
                    )
                  : Container(color: placeholderColor),
              Positioned(
                top: 12,
                left: 12,
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (isCitizen)
                      _Badge(
                        label: 'ON THE GROUND',
                        bgColor: _P.citizenSoft,
                        textColor: _P.citizen,
                      ),
                    if (item.category != null)
                      _Badge(
                        label: item.category!.toUpperCase(),
                        bgColor: _categoryBg(item.category!),
                        textColor: _categoryFg(item.category!),
                      ),
                    if (item.status != null) _StatusBadge(item.status!),
                  ],
                ),
              ),
              if (imageUrls.length > 1)
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${imageIndex + 1} / ${imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (imageUrls.length > 1)
          _ThumbnailRow(
            urls: imageUrls,
            selected: imageIndex,
            onTap: onImageTap,
          ),
      ],
    );
  }
}

class _ThumbnailRow extends StatelessWidget {
  final List<String> urls;
  final int selected;
  final void Function(int) onTap;
  const _ThumbnailRow({
    required this.urls,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: urls.length,
        separatorBuilder: (_, i) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? _P.navy : _P.hairline,
                  width: active ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                urls[i],
                fit: BoxFit.cover,
                errorBuilder: (context, err, _) =>
                    Container(color: const Color(0xFF5C3317)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Meta row ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final NewsItem item;
  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.locations.isNotEmpty) item.locations.first,
      timeAgo(item.publishedAt),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          if (item.locations.isNotEmpty) ...[
            const Icon(Icons.location_on, size: 13, color: _P.inkTertiary),
            const SizedBox(width: 3),
          ] else ...[
            const Icon(Icons.access_time, size: 13, color: _P.inkTertiary),
            const SizedBox(width: 3),
          ],
          Text(
            parts.join(' · '),
            style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Title + body ──────────────────────────────────────────────────────────────

class _TitleBody extends StatelessWidget {
  final NewsItem item;
  const _TitleBody({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              height: 1.22,
              letterSpacing: -0.4,
            ),
          ),
          if (item.body != null && item.body!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.body!,
              style: const TextStyle(
                fontSize: 15,
                color: _P.inkSecondary,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Read article button (wire only) ───────────────────────────────────────────

class _ReadArticleButton extends StatelessWidget {
  final String url;
  const _ReadArticleButton({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Read full article'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _P.navy,
          side: BorderSide(color: _P.navy.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ── Verification panel (citizen only) ────────────────────────────────────────

class _VerificationPanel extends StatelessWidget {
  final NewsItem item;
  final String? userVote;
  final VoidCallback onConfirm;
  final VoidCallback onFlag;
  const _VerificationPanel({
    required this.item,
    required this.userVote,
    required this.onConfirm,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.confirmCount + item.disputeCount;
    final ratio = total == 0 ? 0.5 : item.confirmCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Community verification',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _P.ink,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '$total reviews',
                  style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 4,
                child: Row(
                  children: [
                    Expanded(
                      flex: (ratio * 100).round(),
                      child: Container(color: _P.verified),
                    ),
                    Expanded(
                      flex: 100 - (ratio * 100).round(),
                      child: Container(color: _P.disputed),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${item.confirmCount} verified',
                  style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
                ),
                const Spacer(),
                Text(
                  '${item.disputeCount} flagged',
                  style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    label: 'Confirm',
                    icon: userVote == 'confirm'
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    active: userVote == 'confirm',
                    activeColor: _P.verified,
                    onTap: onConfirm,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VoteButton(
                    label: 'Flag',
                    icon: userVote == 'dispute'
                        ? Icons.flag
                        : Icons.flag_outlined,
                    active: userVote == 'dispute',
                    activeColor: _P.disputed,
                    onTap: onFlag,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _VoteButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? activeColor : _P.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? activeColor : _P.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? Colors.white : _P.inkSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _P.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compare CTA ───────────────────────────────────────────────────────────────

class _CompareCTA extends StatelessWidget {
  final NewsItem item;
  const _CompareCTA({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => context.push('/compare', extra: item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _P.navySoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _P.navy.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows, size: 22, color: _P.navy),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compare with other sources',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _P.navy,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'See how major outlets covered this',
                      style: TextStyle(fontSize: 11.5, color: _P.navy),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _P.navy),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Discussion section ────────────────────────────────────────────────────────

class _DiscussionSection extends StatelessWidget {
  final NewsItem item;
  final List<Comment> comments;
  const _DiscussionSection({required this.item, required this.comments});

  @override
  Widget build(BuildContext context) {
    final preview = comments.isNotEmpty ? comments.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'DISCUSSION',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _P.inkTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (comments.isNotEmpty)
                  GestureDetector(
                    onTap: () => showCommentsSheet(
                      context,
                      reportId: item.id,
                      title: item.title,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'View all ${comments.length}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _P.navy,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward,
                          size: 13,
                          color: _P.navy,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => showCommentsSheet(
                  context,
                  reportId: item.id,
                  title: item.title,
                ),
                child: _CommentPreviewCard(comment: preview),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No comments yet',
                style: TextStyle(fontSize: 13, color: _P.inkTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentPreviewCard extends StatelessWidget {
  final Comment comment;
  const _CommentPreviewCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (comment.type) {
      CommentType.confirm => _P.verified,
      CommentType.dispute => _P.disputed,
      CommentType.context => _P.inkTertiary,
    };

    return Container(
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.hairlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'token #${comment.authorToken.substring(0, 4)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _P.inkSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(comment.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: _P.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: _P.ink,
                        height: 1.5,
                      ),
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

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool isCitizen;
  final VoidCallback onComment;
  const _ActionBar({required this.isCitizen, required this.onComment});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: _P.card,
        border: Border(top: BorderSide(color: _P.hairlineSoft, width: 0.5)),
      ),
      child: Row(
        children: [
          if (isCitizen) ...[
            Expanded(
              child: _BarButton(
                label: 'Comment',
                icon: Icons.chat_bubble_outline,
                outlined: true,
                onTap: onComment,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BarButton(
                label: 'Share',
                icon: Icons.share_outlined,
                outlined: false,
                onTap: () {},
              ),
            ),
          ] else
            Expanded(
              child: _BarButton(
                label: 'Share',
                icon: Icons.share_outlined,
                outlined: false,
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool outlined;
  final VoidCallback onTap;
  const _BarButton({
    required this.label,
    required this.icon,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : _P.navy,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: _P.hairline) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: outlined ? _P.inkSecondary : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: outlined ? _P.inkSecondary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ItemStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ItemStatus.verified => ('VERIFIED', const Color(0xFFDCFCE7), _P.verified),
      ItemStatus.disputed => ('DISPUTED', _P.disputedSoft, _P.disputed),
      ItemStatus.pending => (
        'PENDING',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
      ),
    };
    return _Badge(label: label, bgColor: bg, textColor: fg);
  }
}

Color _categoryBg(String category) => switch (category) {
  'combat' => const Color(0xFFFEE2E2),
  'aid' => const Color(0xFFD1FAE5),
  'alert' => const Color(0xFFFEF3C7),
  'displaced' => const Color(0xFFF3E8FF),
  'infra' => const Color(0xFFDBEAFE),
  _ => const Color(0xFFF3F4F6),
};

Color _categoryFg(String category) => switch (category) {
  'combat' => AppColors.reportCatCombat,
  'aid' => AppColors.reportCatAid,
  'alert' => AppColors.reportCatAlert,
  'displaced' => AppColors.reportCatDisplaced,
  'infra' => AppColors.reportCatInfra,
  _ => AppColors.reportCatOther,
};
