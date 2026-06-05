import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../comments/presentation/widgets/comments_sheet.dart';
import '../../domain/entities/my_report.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _C {
  static const bg = Colors.white;
  static const surface = Color(0xFFF8F9FA);
  static const ink = Color(0xFF212529);
  static const inkSub = Color(0xFF495057);
  static const inkMuted = Color(0xFF868E96);
  static const hairline = Color(0xFFE9ECEF);
  static const navy = AppColors.reportNavy;
  static const citizen = Color(0xFFB45309);
  static const verified = Color(0xFF1F7A3F);
  static const verifiedBg = Color(0xFFECFDF5);
  static const disputed = Color(0xFFB42318);
  static const discussionAccent = Color(0xFF22C55E);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MyReportDetailScreen extends StatefulWidget {
  final String reportId;
  final MyReport? report;

  const MyReportDetailScreen({super.key, required this.reportId, this.report});

  @override
  State<MyReportDetailScreen> createState() => _MyReportDetailScreenState();
}

class _MyReportDetailScreenState extends State<MyReportDetailScreen> {
  late final PageController _pageCtrl;
  int _photoIndex = 0;
  bool _bookmarked = false;

  MyReport? get _report => widget.report;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPhoto(int i) {
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Report not found')),
      );
    }

    final photos = report.photos;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            // ── Pinned app bar ──────────────────────────────────────────────
            _DetailAppBar(
              status: report.status,
              bookmarked: _bookmarked,
              onBack: () => Navigator.of(context).pop(),
              onShare: () => _showShare(context, report),
              onBookmark: () => setState(() => _bookmarked = !_bookmarked),
            ),

            // ── Scrollable content ──────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero image (swipeable PageView)
                        _HeroSection(
                          photos: photos,
                          index: _photoIndex,
                          pageCtrl: _pageCtrl,
                          status: report.status,
                          onPageChanged: (i) => setState(() => _photoIndex = i),
                        ),

                        // Thumbnail strip
                        if (photos.length > 1)
                          _ThumbnailStrip(
                            photos: photos,
                            selected: _photoIndex,
                            onTap: _goToPhoto,
                          ),

                        const Divider(height: 1, color: _C.hairline),

                        // Meta row
                        _MetaRow(report: report),

                        // Title
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: Text(
                            report.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _C.ink,
                              height: 1.25,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),

                        // Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Text(
                            report.body,
                            style: const TextStyle(
                              fontSize: 15,
                              color: _C.inkSub,
                              height: 1.65,
                            ),
                          ),
                        ),

                        const Divider(height: 1, color: _C.hairline),

                        // Discussion preview
                        _DiscussionSection(report: report),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom bar ──────────────────────────────────────────────────
            _BottomBar(report: report),
          ],
        ),
      ),
    );
  }

  void _showShare(BuildContext ctx, MyReport report) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareSheet(report: report),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _DetailAppBar extends StatelessWidget {
  final String status;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const _DetailAppBar({
    required this.status,
    required this.bookmarked,
    required this.onBack,
    required this.onShare,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _CircleBtn(icon: Icons.arrow_back, onTap: onBack),
            const SizedBox(width: 12),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _C.citizen,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'CITIZEN REPORT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _C.citizen,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            _CircleBtn(icon: Icons.share_outlined, onTap: onShare),
            const SizedBox(width: 8),
            _CircleBtn(
              icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
              iconColor: bookmarked ? _C.navy : null,
              onTap: onBookmark,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _C.surface,
          border: Border.all(color: _C.hairline),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? _C.ink),
      ),
    );
  }
}

// ── Hero section (swipeable) ──────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final List<String> photos;
  final int index;
  final PageController pageCtrl;
  final String status;
  final void Function(int) onPageChanged;

  const _HeroSection({
    required this.photos,
    required this.index,
    required this.pageCtrl,
    required this.status,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Swipeable photos
          photos.isNotEmpty
              ? PageView.builder(
                  controller: pageCtrl,
                  onPageChanged: onPageChanged,
                  itemCount: photos.length,
                  itemBuilder: (ctx, i) => Image.network(
                    photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) => const _HeroPlaceholder(),
                  ),
                )
              : const _HeroPlaceholder(),

          // Status badge — top left
          Positioned(top: 12, left: 12, child: _StatusBadge(status: status)),

          // Photo counter — bottom right
          if (photos.length > 1)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${index + 1} / ${photos.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFCED4DA),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF868E96), size: 48),
      ),
    );
  }
}

// ── Thumbnail strip ───────────────────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  final List<String> photos;
  final int selected;
  final void Function(int) onTap;

  const _ThumbnailStrip({
    required this.photos,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i < photos.length; i++) ...[
            GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == selected ? _C.navy : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) => Container(color: _C.hairline),
                  ),
                ),
              ),
            ),
            if (i < photos.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, label, bg, fg) = switch (status) {
      'confirmed' => (
        Icons.check_circle_outline,
        'VERIFIED',
        _C.verifiedBg,
        _C.verified,
      ),
      'disputed' => (
        Icons.error_outline,
        'DISPUTED',
        const Color(0xFFFEE2E2),
        _C.disputed,
      ),
      _ => (
        Icons.schedule_outlined,
        'PENDING',
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (report.location.isNotEmpty) ...[
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: _C.inkMuted,
            ),
            const SizedBox(width: 3),
            Text(
              report.location,
              style: const TextStyle(fontSize: 13, color: _C.inkMuted),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('·', style: TextStyle(color: _C.inkMuted)),
            ),
          ],
          const Icon(Icons.schedule_outlined, size: 14, color: _C.inkMuted),
        ],
      ),
    );
  }
}

// ── Discussion preview ────────────────────────────────────────────────────────

class _DiscussionSection extends StatelessWidget {
  final MyReport report;
  const _DiscussionSection({required this.report});

  @override
  Widget build(BuildContext context) {
    final hasPreview = (report.previewCommentContent ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'DISCUSSION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.inkMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (report.commentCount > 0)
                GestureDetector(
                  onTap: () => showCommentsSheet(
                    context,
                    reportId: report.id,
                    title: report.title,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all ${report.commentCount}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _C.navy,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward, size: 14, color: _C.navy),
                    ],
                  ),
                ),
            ],
          ),
          if (hasPreview) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: _C.discussionAccent, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        report.previewCommentToken ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(report.previewCommentAt ?? report.submittedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.previewCommentContent ?? '',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _C.inkSub,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'No discussion yet. Be the first to add context.',
              style: TextStyle(fontSize: 13, color: _C.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final MyReport report;
  const _BottomBar({required this.report});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: const BoxDecoration(
        color: _C.bg,
        border: Border(top: BorderSide(color: _C.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showCommentsSheet(
                context,
                reportId: report.id,
                title: report.title,
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 17),
              label: const Text(
                'Comment',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.ink,
                side: const BorderSide(color: Color(0xFFDEE2E6)),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: 'https://frontline.app/report/${report.id}',
                  ),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Link copied')));
              },
              icon: const Icon(Icons.share_outlined, size: 17),
              label: const Text(
                'Share',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _C.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Share sheet ───────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  final MyReport report;
  const _ShareSheet({required this.report});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Share report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.ink,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: _C.inkMuted, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              report.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _C.inkMuted),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SBtn(
                  icon: Icons.link,
                  label: 'Copy link',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: 'https://frontline.app/report/${report.id}',
                      ),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  },
                ),
                _SBtn(
                  icon: Icons.send_outlined,
                  label: 'Telegram',
                  onTap: () => Navigator.pop(context),
                ),
                _SBtn(
                  icon: Icons.message_outlined,
                  label: 'WhatsApp',
                  onTap: () => Navigator.pop(context),
                ),
                _SBtn(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'The shared link only shows the public report — your identity remains anonymous.',
              style: TextStyle(fontSize: 11, color: _C.inkMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.hairline),
            ),
            child: Icon(icon, color: _C.inkMuted, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: _C.inkMuted)),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
