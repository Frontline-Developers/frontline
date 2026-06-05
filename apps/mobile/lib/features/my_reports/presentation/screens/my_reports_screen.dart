import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../comments/presentation/providers/comments_provider.dart';
import '../../../../core/widgets/scroll_nav_buttons.dart';
import '../../../comments/presentation/widgets/comments_sheet.dart';
import '../../domain/entities/my_report.dart';
import '../providers/my_reports_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const cardBorder = Color(0xFFE9ECEF);
  static const ink = Color(0xFF212529);
  static const inkSub = Color(0xFF495057);
  static const inkMuted = Color(0xFF868E96);
  static const navy = AppColors.reportNavy;
  static const verified = Color(0xFF1F7A3F);
  static const verifiedBg = Color(0xFFECFDF5);
  static const pending = Color(0xFFB45309);
  static const pendingBg = Color(0xFFFEF3C7);
  static const disputed = Color(0xFFB42318);
  static const disputedBg = Color(0xFFFEE2E2);
  static const divider = Color(0xFFE9ECEF);
}

const _kMaxWidth = 700.0;

// ── Screen ────────────────────────────────────────────────────────────────────

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myReportsNotifierProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: ColoredBox(
          color: _C.bg,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AppBar(
                  onExportTap: () => _showExportSheet(context, state.reports),
                ),
                _AggregateStats(state: state),
                const Divider(height: 1, color: _C.divider),
                const SizedBox(height: 8),
                _FilterRow(
                  selected: state.filter,
                  counts: {
                    for (final f in MyReportsFilter.values)
                      f: state.countFor(f),
                  },
                  onChanged: (f) =>
                      ref.read(myReportsNotifierProvider.notifier).setFilter(f),
                ),
                if (state.isTruncated) _TruncationBanner(),
                const SizedBox(height: 4),
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _C.navy),
                        )
                      : state.error != null
                      ? _ErrorState(message: state.error!)
                      : state.filtered.isEmpty
                      ? _EmptyState(filter: state.filter)
                      : _ReportList(
                          reports: state.filtered,
                          isDeleting: state.isDeleting,
                          onDelete: (r) => _showDeleteModal(context, ref, r),
                          onShare: (r) => _showShareSheet(context, r),
                          onComment: (r) => showCommentsSheet(
                            context,
                            reportId: r.id,
                            title: r.title,
                          ),
                          onTapCard: (r) =>
                              context.push('/report/${r.id}', extra: r),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext ctx, List<MyReport> reports) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _C.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExportTokensSheet(reports: reports),
    );
  }

  void _showShareSheet(BuildContext ctx, MyReport report) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareSheet(report: report),
    );
  }

  void _showDeleteModal(BuildContext ctx, WidgetRef ref, MyReport report) {
    showDialog(
      context: ctx,
      builder: (_) => _DeleteConfirmModal(
        report: report,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await ref
              .read(myReportsNotifierProvider.notifier)
              .deleteReport(report.id, report.token);
        },
      ),
    );
  }
}

// ── Truncation notice ─────────────────────────────────────────────────────────

class _TruncationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border.all(color: const Color(0xFFFFDC7C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF856404)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing your 30 most recent reports. Older reports are not displayed.',
              style: TextStyle(fontSize: 12, color: const Color(0xFF856404)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final VoidCallback onExportTap;
  const _AppBar({required this.onExportTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          const Icon(
            Icons.folder_shared_outlined,
            size: 18,
            color: _C.inkMuted,
          ),
          const SizedBox(width: 7),
          const Text(
            'My reports',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.ink,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onExportTap,
            icon: const Icon(Icons.key_outlined, color: _C.inkMuted, size: 21),
            tooltip: 'Export tokens',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

// ── Aggregate stats ───────────────────────────────────────────────────────────

class _AggregateStats extends StatelessWidget {
  final MyReportsState state;
  const _AggregateStats({required this.state});

  @override
  Widget build(BuildContext context) {
    final total = state.reports.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total submission${total == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _C.ink,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stored locally — only the tokens are tied to your device.',
            style: TextStyle(fontSize: 12, color: _C.inkMuted),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatCol(
                value: '${state.verifiedCount}',
                label: 'VERIFIED',
                color: _C.verified,
              ),
              const SizedBox(width: 24),
              _StatCol(
                value: _compact(state.totalConfirms),
                label: 'CONFIRMS',
                color: _C.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCol({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _C.inkMuted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final MyReportsFilter selected;
  final Map<MyReportsFilter, int> counts;
  final void Function(MyReportsFilter) onChanged;

  const _FilterRow({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  static const _labels = {
    MyReportsFilter.all: 'All',
    MyReportsFilter.verified: 'Verified',
    MyReportsFilter.pending: 'Pending',
    MyReportsFilter.disputed: 'Disputed',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final f in MyReportsFilter.values) ...[
            _FilterTab(
              label: _labels[f]!,
              count: counts[f] ?? 0,
              selected: selected == f,
              onTap: () => onChanged(f),
            ),
            if (f != MyReportsFilter.disputed) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _C.ink : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _C.ink : const Color(0xFFDEE2E6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : _C.inkSub,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : _C.cardBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _C.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Report list ───────────────────────────────────────────────────────────────

class _ReportList extends StatefulWidget {
  final List<MyReport> reports;
  final bool isDeleting;
  final void Function(MyReport) onDelete;
  final void Function(MyReport) onShare;
  final void Function(MyReport) onComment;
  final void Function(MyReport) onTapCard;

  const _ReportList({
    required this.reports,
    required this.isDeleting,
    required this.onDelete,
    required this.onShare,
    required this.onComment,
    required this.onTapCard,
  });

  @override
  State<_ReportList> createState() => _ReportListState();
}

class _ReportListState extends State<_ReportList> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollNavButtons.wrap(
      controller: _ctrl,
      child: ListView.builder(
        controller: _ctrl,
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        itemCount: widget.reports.length + 1,
        itemBuilder: (ctx, i) {
          if (i == widget.reports.length) return const _ExplainerCard();
          final r = widget.reports[i];
          return _ReportCard(
            report: r,
            onDelete: () => widget.onDelete(r),
            onShare: () => widget.onShare(r),
            onComment: () => widget.onComment(r),
            onTap: () => widget.onTapCard(r),
          );
        },
      ),
    );
  }
}

// ── Report card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final MyReport report;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onComment;
  final VoidCallback onTap;

  const _ReportCard({
    required this.report,
    required this.onDelete,
    required this.onShare,
    required this.onComment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTopStrip(report: report, onDelete: onDelete),
              const Divider(height: 1, color: _C.divider),
              _CardBody(report: report, onTap: onTap),
              if (report.status == 'pending' ||
                  report.status == 'disputed') ...[
                _VerifyMeter(confirms: report.confirms, flags: report.flags),
              ],
              const Divider(height: 1, color: _C.divider),
              _ActionRow(
                report: report,
                onComment: onComment,
                onShare: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card top strip ────────────────────────────────────────────────────────────

class _CardTopStrip extends StatelessWidget {
  final MyReport report;
  final VoidCallback onDelete;

  const _CardTopStrip({required this.report, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          _StatusBadge(status: report.status),
          const SizedBox(width: 8),
          _TokenChip(preview: report.tokenPreview),
          const Spacer(),
          Text(
            _dateTimeLabel(report.submittedAt),
            style: const TextStyle(fontSize: 11, color: _C.inkMuted),
          ),
          if (report.status == 'disputed') ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: _C.disputed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        _C.disputedBg,
        _C.disputed,
      ),
      _ => (Icons.schedule_outlined, 'PENDING', _C.pendingBg, _C.pending),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  final String preview;
  const _TokenChip({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.key_outlined, size: 11, color: _C.inkMuted),
          const SizedBox(width: 3),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: _C.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card body ─────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final MyReport report;
  final VoidCallback onTap;

  const _CardBody({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(photo: report.photo, category: report.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.location.isNotEmpty) ...[
                    Text(
                      report.location,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _C.inkSub,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? photo;
  final String category;
  const _Thumbnail({required this.photo, required this.category});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo != null
                ? Image.network(
                    photo!,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, s) => const _ThumbPlaceholder(),
                  )
                : const _ThumbPlaceholder(),
            Positioned(
              bottom: 5,
              left: 5,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _categoryColor(category),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  _categoryIcon(category),
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9ECEF),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFADB5BD), size: 24),
      ),
    );
  }
}

// ── Verify meter ──────────────────────────────────────────────────────────────

class _VerifyMeter extends StatelessWidget {
  final int confirms;
  final int flags;
  const _VerifyMeter({required this.confirms, required this.flags});

  @override
  Widget build(BuildContext context) {
    final total = confirms + flags;
    final ratio = total == 0 ? 0.5 : confirms / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: (ratio * 100).round(),
                    child: Container(color: _C.verified),
                  ),
                  Expanded(
                    flex: 100 - (ratio * 100).round(),
                    child: Container(color: _C.disputed),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 11,
                    color: _C.verified,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$confirms verified',
                    style: const TextStyle(fontSize: 11, color: _C.verified),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_outlined, size: 11, color: _C.inkMuted),
                  const SizedBox(width: 3),
                  Text(
                    '$flags flagged',
                    style: const TextStyle(fontSize: 11, color: _C.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends ConsumerWidget {
  final MyReport report;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _ActionRow({
    required this.report,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read live comment count from Firestore so it's always accurate,
    // even if the denormalized commentCount on the report doc is stale.
    final liveCount = ref
        .watch(commentsStreamProvider(report.id))
        .when(
          data: (c) => c.length,
          loading: () => report.commentCount,
          error: (e, s) => report.commentCount,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 13, color: _C.inkMuted),
          const SizedBox(width: 3),
          _MetricText(number: _commaNum(report.confirms), label: ' confirms'),
          if (report.flags > 0) ...[
            const SizedBox(width: 10),
            const Icon(Icons.flag_outlined, size: 13, color: _C.inkMuted),
            const SizedBox(width: 3),
            _MetricText(number: _commaNum(report.flags), label: ' flags'),
          ],
          const Spacer(),
          // Comment pill — light blue bg, navy text
          GestureDetector(
            onTap: onComment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDF8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 13,
                    color: _C.navy,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$liveCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _C.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Share — gray border bg
          GestureDetector(
            onTap: onShare,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _C.cardBorder),
              ),
              child: const Icon(
                Icons.share_outlined,
                size: 15,
                color: _C.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricText extends StatelessWidget {
  final String number;
  final String label;
  const _MetricText({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: number,
            style: const TextStyle(
              fontSize: 12,
              color: _C.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12, color: _C.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ── Explainer card ────────────────────────────────────────────────────────────

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.cardBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, size: 14, color: _C.inkMuted),
                  SizedBox(width: 6),
                  Text(
                    'Why can I only delete disputed ones?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Verified and pending reports may be the only record of an event. Once the community is reviewing them, removing them quietly would undermine the archive. Disputed reports — where the community is already calling them into question — are safe to retract.',
                style: TextStyle(fontSize: 12, color: _C.inkSub, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty & error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final MyReportsFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, msg) = switch (filter) {
      MyReportsFilter.disputed => (
        Icons.check_circle_outline,
        'No disputed reports.\nKeep it up!',
      ),
      MyReportsFilter.verified => (
        Icons.verified_outlined,
        'No verified reports yet.',
      ),
      MyReportsFilter.pending => (Icons.hourglass_empty, 'No pending reports.'),
      MyReportsFilter.all => (
        Icons.folder_open_outlined,
        'No submissions yet.\nYour anonymous reports will appear here.',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: _C.inkMuted),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.inkMuted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _C.disputed, fontSize: 13),
        ),
      ),
    );
  }
}

// ── Delete confirm modal ──────────────────────────────────────────────────────

class _DeleteConfirmModal extends StatelessWidget {
  final MyReport report;
  final VoidCallback onConfirm;

  const _DeleteConfirmModal({required this.report, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trash icon in soft red circle
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: _C.disputed,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete this report?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _C.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${report.title}"',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: _C.inkSub,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.disputedBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.disputed.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'The post will be removed from public view immediately. The anonymous token will be invalidated. This cannot be undone.',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 13, color: _C.disputed, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.inkSub,
                      side: const BorderSide(color: _C.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA81F1F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
              style: const TextStyle(fontSize: 13, color: _C.inkSub),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareBtn(
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
                _ShareBtn(
                  icon: Icons.send_outlined,
                  label: 'Telegram',
                  onTap: () => Navigator.pop(context),
                ),
                _ShareBtn(
                  icon: Icons.message_outlined,
                  label: 'WhatsApp',
                  onTap: () => Navigator.pop(context),
                ),
                _ShareBtn(
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

class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
              color: _C.divider,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _C.inkSub, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: _C.inkMuted)),
        ],
      ),
    );
  }
}

// ── Export tokens sheet ───────────────────────────────────────────────────────

class _ExportTokensSheet extends StatelessWidget {
  final List<MyReport> reports;
  const _ExportTokensSheet({required this.reports});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.key_outlined,
                    color: _C.navy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Export tokens',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _C.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Back these up to access reports elsewhere',
                        style: TextStyle(fontSize: 13, color: _C.inkMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: _C.inkMuted, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Warning banner
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Anyone with these tokens can manage your reports. Store them somewhere safe — we can't recover them.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB45309),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Token cards
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: reports.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) =>
                    _TokenCard(report: reports[i], sheetCtx: ctx),
              ),
            ),
            const SizedBox(height: 16),
            // Download button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // TODO: encrypt and save to file (flutter_file_dialog / path_provider)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Encrypted file download — coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text(
                  'Download all as encrypted file',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  final MyReport report;
  final BuildContext sheetCtx;
  const _TokenCard({required this.report, required this.sheetCtx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.token,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: _C.ink,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  report.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _C.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: report.token));
              ScaffoldMessenger.of(
                sheetCtx,
              ).showSnackBar(const SnackBar(content: Text('Token copied')));
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.cardBorder),
              ),
              child: const Icon(
                Icons.copy_outlined,
                size: 16,
                color: _C.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

String _commaNum(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  final offset = s.length % 3;
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _dateTimeLabel(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day} · $h:$m';
}

// Icons and colours match reportCategoryStyles in report_theme.dart
Color _categoryColor(String cat) => switch (cat) {
  'combat' => AppColors.reportCatCombat,
  'aid' => AppColors.reportCatAid,
  'alert' => AppColors.reportCatAlert,
  'displaced' => AppColors.reportCatDisplaced,
  'infra' => AppColors.reportCatInfra,
  _ => AppColors.reportCatOther,
};

IconData _categoryIcon(String cat) => switch (cat) {
  'combat' => Icons.crisis_alert,
  'aid' => Icons.favorite,
  'alert' => Icons.warning_rounded,
  'displaced' => Icons.groups,
  'infra' => Icons.business,
  _ => Icons.more_horiz,
};
