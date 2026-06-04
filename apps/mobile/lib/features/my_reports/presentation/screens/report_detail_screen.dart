import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../comments/presentation/providers/comments_provider.dart';
import '../../../comments/presentation/widgets/comments_sheet.dart';
import '../../../feed/presentation/providers/vote_provider.dart';
import '../../domain/entities/my_report.dart';

// ── Palette — mirrors reporting/presentation/screens/report_detail_screen ─────

class _P {
  static const surface = AppColors.reportSurface;
  static const card = AppColors.reportSurfaceCard;
  static const raised = AppColors.reportSurfaceRaised;
  static const navy = AppColors.reportNavy;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const hairlineSoft = AppColors.reportHairlineSoft;
  static const citizen = Color(0xFFB54708);
  static const citizenSoft = Color(0xFFFEF3C7);
  static const verified = AppColors.reportVerified;
  static const disputed = AppColors.reportDisputed;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MyReportDetailScreen extends ConsumerStatefulWidget {
  final String reportId;
  final MyReport? report;

  const MyReportDetailScreen({super.key, required this.reportId, this.report});

  @override
  ConsumerState<MyReportDetailScreen> createState() =>
      _MyReportDetailScreenState();
}

class _MyReportDetailScreenState extends ConsumerState<MyReportDetailScreen> {
  int _imageIndex = 0;
  bool _bookmarked = false;

  MyReport? get _report => widget.report;

  Future<void> _castVote(String type) async {
    final ds = ref.read(voteDatasourceProvider);
    await ds.castVote(widget.reportId, type);
    ref.invalidate(voteProvider(widget.reportId));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _P.card,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18, color: _P.ink),
            onPressed: () => context.pop(),
          ),
        ),
        backgroundColor: _P.surface,
        body: const Center(child: Text('Report not found')),
      );
    }

    final voteAsync = ref.watch(voteProvider(widget.reportId));
    final userVote = voteAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (e, _) => null,
    );

    final commentsAsync = ref.watch(commentsStreamProvider(widget.reportId));
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
                  report: report,
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
                          report: report,
                          imageIndex: _imageIndex,
                          onImageTap: (i) => setState(() => _imageIndex = i),
                        ),
                        _MetaRow(report: report),
                        _TitleBody(report: report),
                        _VerificationPanel(
                          report: report,
                          userVote: userVote,
                          onConfirm: () => _castVote('confirm'),
                          onFlag: () => _castVote('dispute'),
                        ),
                        _DiscussionSection(report: report, comments: comments),
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
            child: _ActionBar(reportId: widget.reportId, title: report.title),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final MyReport report;
  final bool bookmarked;
  final VoidCallback onBookmark;

  const _TopBar({
    required this.report,
    required this.bookmarked,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _P.citizen,
            ),
          ),
          const SizedBox(width: 5),
          const Expanded(
            child: Text(
              'CITIZEN REPORT',
              style: TextStyle(
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
  final MyReport report;
  final int imageIndex;
  final void Function(int) onImageTap;

  const _HeroSection({
    required this.report,
    required this.imageIndex,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final photos = report.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              photos.isNotEmpty
                  ? Image.network(
                      photos[imageIndex.clamp(0, photos.length - 1)],
                      fit: BoxFit.cover,
                      errorBuilder: (context, err, _) =>
                          Container(color: const Color(0xFF5C3317)),
                    )
                  : Container(color: const Color(0xFF5C3317)),
              Positioned(
                top: 12,
                left: 12,
                child: Wrap(
                  spacing: 6,
                  children: [
                    _Badge(
                      label: 'ON THE GROUND',
                      bgColor: _P.citizenSoft,
                      textColor: _P.citizen,
                    ),
                    if (report.category.isNotEmpty)
                      _Badge(
                        label: report.category.toUpperCase(),
                        bgColor: _categoryBg(report.category),
                        textColor: _categoryFg(report.category),
                      ),
                    _StatusBadge(status: report.status),
                  ],
                ),
              ),
              if (photos.length > 1)
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
                      '${imageIndex + 1} / ${photos.length}',
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
        if (photos.length > 1)
          _ThumbnailRow(urls: photos, selected: imageIndex, onTap: onImageTap),
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
  final MyReport report;
  const _MetaRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          if (report.location.isNotEmpty) ...[
            const Icon(Icons.location_on, size: 13, color: _P.inkTertiary),
            const SizedBox(width: 3),
            Text(
              '${report.location} · ${timeAgo(report.submittedAt)}',
              style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
            ),
          ] else ...[
            const Icon(Icons.access_time, size: 13, color: _P.inkTertiary),
            const SizedBox(width: 3),
            Text(
              timeAgo(report.submittedAt),
              style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Title + body ──────────────────────────────────────────────────────────────

class _TitleBody extends StatelessWidget {
  final MyReport report;
  const _TitleBody({required this.report});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              height: 1.22,
              letterSpacing: -0.4,
            ),
          ),
          if (report.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              report.body,
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

// ── Verification panel ────────────────────────────────────────────────────────

class _VerificationPanel extends StatelessWidget {
  final MyReport report;
  final String? userVote;
  final VoidCallback onConfirm;
  final VoidCallback onFlag;

  const _VerificationPanel({
    required this.report,
    required this.userVote,
    required this.onConfirm,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    final total = report.confirms + report.flags;
    final ratio = total == 0 ? 0.5 : report.confirms / total;

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
                  '${report.confirms} verified',
                  style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
                ),
                const Spacer(),
                Text(
                  '${report.flags} flagged',
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

// ── Discussion section ────────────────────────────────────────────────────────

class _DiscussionSection extends StatelessWidget {
  final MyReport report;
  final List<Comment> comments;

  const _DiscussionSection({required this.report, required this.comments});

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
                      reportId: report.id,
                      title: report.title,
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
                  reportId: report.id,
                  title: report.title,
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
                          'token #${comment.authorToken.substring(0, comment.authorToken.length.clamp(0, 4))}',
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
  final String reportId;
  final String title;

  const _ActionBar({required this.reportId, required this.title});

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
          Expanded(
            child: _BarButton(
              label: 'Comment',
              icon: Icons.chat_bubble_outline,
              outlined: true,
              onTap: () =>
                  showCommentsSheet(context, reportId: reportId, title: title),
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
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'verified' => (
        'VERIFIED',
        const Color(0xFFDCFCE7),
        AppColors.reportVerified,
      ),
      'disputed' => (
        'DISPUTED',
        const Color(0xFFFEE2E2),
        AppColors.reportDisputed,
      ),
      _ => ('PENDING', const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
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
