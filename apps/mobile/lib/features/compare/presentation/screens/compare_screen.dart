import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../providers/compare_provider.dart';

// ── Palette (mirrors feed/reporting light-mode) ───────────────────────────────

class _P {
  static const surface = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const navy = AppColors.reportNavy;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const citizen = Color(0xFFB54708);
  static const citizenSoft = Color(0xFFFEF3C7);
  static const citizenDot = AppColors.accentCitizen;
  static const wireDot = AppColors.accentWire;
  static const verified = AppColors.reportVerified;
  static const verifiedSoft = AppColors.reportVerifiedSoft;
  static const disputed = AppColors.reportDisputed;
  static const disputedSoft = Color(0xFFFEE2E2);
  static const pending = Color(0xFF6B7280);
  static const pendingSoft = Color(0xFFF3F4F6);
}

enum _ViewMode { timeline, columns }

// ── Screen ────────────────────────────────────────────────────────────────────

class CompareScreen extends ConsumerStatefulWidget {
  final String? reportId;
  const CompareScreen({super.key, this.reportId});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  _ViewMode _mode = _ViewMode.timeline;

  @override
  void initState() {
    super.initState();
    if (widget.reportId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(compareNotifierProvider.notifier).load(widget.reportId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compareNotifierProvider);

    return Scaffold(
      backgroundColor: _P.surface,
      appBar: AppBar(
        backgroundColor: _P.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: context.canPop()
            ? BackButton(color: _P.ink, onPressed: () => context.pop())
            : null,
        title: const Text(
          'Compare Coverage',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _P.ink,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _P.hairline),
        ),
      ),
      body: widget.reportId == null
          ? const _NoReportHint()
          : state.isLoading
          ? const Center(child: CircularProgressIndicator(color: _P.navy))
          : state.error != null
          ? _ErrorState(error: state.error!)
          : state.report == null
          ? const _NoReportHint()
          : Column(
              children: [
                _HeroCard(
                  report: state.report!,
                  wireCount: state.wireNews.length,
                ),
                _ViewToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                Expanded(
                  child: _mode == _ViewMode.timeline
                      ? _TimelineView(
                          report: state.report!,
                          wireNews: state.wireNews,
                        )
                      : _ColumnsView(
                          report: state.report!,
                          wireNews: state.wireNews,
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final NewsItem report;
  final int wireCount;
  const _HeroCard({required this.report, required this.wireCount});

  @override
  Widget build(BuildContext context) {
    final status = report.status ?? ItemStatus.pending;
    final (statusLabel, statusBg, statusFg) = switch (status) {
      ItemStatus.verified => ('Report verified', _P.verifiedSoft, _P.verified),
      ItemStatus.disputed => ('Report disputed', _P.disputedSoft, _P.disputed),
      ItemStatus.pending => ('Pending review', _P.pendingSoft, _P.pending),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(label: statusLabel, bg: statusBg, fg: statusFg),
              _Pill(label: '1 citizen', bg: _P.citizenSoft, fg: _P.citizen),
              _Pill(
                label: '$wireCount wire source${wireCount == 1 ? '' : 's'}',
                bg: const Color(0xFFDBEAF5),
                fg: _P.wireDot,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Citizen report vs. recent wire coverage',
            style: TextStyle(fontSize: 12, color: _P.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ── View toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final _ViewMode mode;
  final void Function(_ViewMode) onChanged;
  const _ViewToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECEF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _ToggleBtn(
              label: 'Timeline',
              active: mode == _ViewMode.timeline,
              onTap: () => onChanged(_ViewMode.timeline),
            ),
            _ToggleBtn(
              label: 'Columns',
              active: mode == _ViewMode.columns,
              onTap: () => onChanged(_ViewMode.columns),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? _P.card : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? _P.ink : _P.inkTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Timeline view ─────────────────────────────────────────────────────────────

class _TimelineView extends StatelessWidget {
  final NewsItem report;
  final List<NewsItem> wireNews;
  const _TimelineView({required this.report, required this.wireNews});

  @override
  Widget build(BuildContext context) {
    // Sort wire items by date; the citizen report is always the T+0 anchor
    // regardless of its position in the sorted list, so the timeline shows
    // how quickly (or slowly) wire sources followed citizen coverage.
    final sortedWire = [...wireNews]
      ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
    final all = [report, ...sortedWire];
    final baseline = report.publishedAt;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: all.length,
      itemBuilder: (_, i) {
        final item = all[i];
        final delta = item.publishedAt.difference(baseline);
        return _TimelineItem(
          item: item,
          delta: item.source == NewsSource.citizen ? null : delta,
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final NewsItem item;
  final Duration? delta;
  const _TimelineItem({required this.item, this.delta});

  @override
  Widget build(BuildContext context) {
    final isCitizen = item.source == NewsSource.citizen;
    final accentColor = isCitizen ? _P.citizenDot : _P.wireDot;
    final sourceLabel = isCitizen
        ? 'CITIZEN REPORT'
        : (item.sourceName?.toUpperCase() ?? 'WIRE NEWS');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _P.card,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: accentColor, width: 3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sourceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (delta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _formatDelta(delta!),
                          style: const TextStyle(
                            fontSize: 10,
                            color: _P.inkTertiary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _P.ink,
                    height: 1.3,
                  ),
                ),
                if (item.body != null && item.body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _P.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  timeAgo(item.publishedAt),
                  style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDelta(Duration d) {
  if (d.inMinutes < 60) return 'T+${d.inMinutes}m';
  if (d.inHours < 24) return 'T+${d.inHours}h';
  return 'T+${d.inDays}d';
}

// ── Columns view ──────────────────────────────────────────────────────────────

class _ColumnsView extends StatelessWidget {
  final NewsItem report;
  final List<NewsItem> wireNews;
  const _ColumnsView({required this.report, required this.wireNews});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SourceColumn(
              label: 'On the ground',
              color: _P.citizenDot,
              items: [report],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SourceColumn(
              label: 'Wire sources',
              color: _P.wireDot,
              items: wireNews,
              emptyMessage: 'No wire coverage found for this report',
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceColumn extends StatelessWidget {
  final String label;
  final Color color;
  final List<NewsItem> items;
  final String? emptyMessage;
  const _SourceColumn({
    required this.label,
    required this.color,
    required this.items,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty && emptyMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _P.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _P.hairline),
            ),
            child: Text(
              emptyMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: _P.inkTertiary,
                height: 1.4,
              ),
            ),
          )
        else
          for (final item in items) ...[
            _ColumnCard(item: item, accentColor: color),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ColumnCard extends StatelessWidget {
  final NewsItem item;
  final Color accentColor;
  const _ColumnCard({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _P.ink,
              height: 1.35,
            ),
          ),
          if (item.body != null && item.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.body!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: _P.inkSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                timeAgo(item.publishedAt),
                style: const TextStyle(fontSize: 10, color: _P.inkTertiary),
              ),
              if (item.source == NewsSource.wire && item.tone != 0) ...[
                const SizedBox(width: 6),
                _ToneChip(tone: item.tone),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _NoReportHint extends StatelessWidget {
  const _NoReportHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows, size: 48, color: _P.inkTertiary),
            SizedBox(height: 16),
            Text(
              'Tap "Compare" on any report in the Feed to see how citizen reporters and wire sources covered the same event.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _P.inkTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _P.disputed, fontSize: 13),
        ),
      ),
    );
  }
}

// ── Tone chip ─────────────────────────────────────────────────────────────────

class _ToneChip extends StatelessWidget {
  final int tone;
  const _ToneChip({required this.tone});

  @override
  Widget build(BuildContext context) {
    final isPositive = tone > 0;
    final label = isPositive ? '+$tone' : '$tone';
    final color = isPositive ? _P.verified : _P.disputed;
    final bg = isPositive ? _P.verifiedSoft : _P.disputedSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
