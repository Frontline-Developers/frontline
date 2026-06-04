import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/vote_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../../domain/entities/event_cluster.dart';
import '../providers/compare_provider.dart';

// ── Palette (mirrors feed_screen.dart) ────────────────────────────────────────

const _kMaxWidth = 700.0;

class _P {
  static const surface = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const navy = AppColors.reportNavy;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const verified = AppColors.reportVerified;
  static const verifiedSoft = AppColors.reportVerifiedSoft;
  static const disputed = AppColors.reportDisputed;
  static const disputedSoft = Color(0xFFFEE2E2);
  static const unverifiedBg = Color(0xFFF3F4F6);
  static const unverifiedFg = Color(0xFF6B7280);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CompareScreen extends ConsumerStatefulWidget {
  final NewsItem? anchorItem;
  const CompareScreen({super.key, this.anchorItem});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compareNotifierProvider);
    final anchor = widget.anchorItem;
    final allClusters = state.clusters;
    final clusters = anchor == null
        ? allClusters
        : allClusters
              .where((c) => c.category == _effectiveCategory(anchor))
              .map(
                (c) => EventCluster(
                  id: c.id,
                  category: c.category,
                  date: c.date,
                  items: c.items.where((i) => i.id != anchor.id).toList(),
                ),
              )
              .where((c) => c.items.isNotEmpty)
              .toList();

    return ColoredBox(
      color: _P.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompareAppBar(onBack: anchor != null ? () => context.pop() : null),
            if (anchor != null) ...[
              _FeaturedItemCard(item: anchor),
              _RelatedReportsHeader(
                count: clusters.fold(0, (s, c) => s + c.items.length),
              ),
            ] else
              _CompareHeader(count: allClusters.length),
            const SizedBox(height: 4),
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _P.navy),
                    )
                  : state.error != null
                  ? _ErrorState(error: state.error!)
                  : clusters.isEmpty
                  ? _EmptyState(hasAnchor: anchor != null)
                  : _ClusterList(clusters: clusters),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _CompareAppBar extends StatelessWidget {
  final VoidCallback? onBack;
  const _CompareAppBar({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios, size: 16, color: _P.ink),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          else ...[
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _P.navy,
              ),
            ),
            const SizedBox(width: 7),
          ],
          const Text(
            'Compare sources',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CompareHeader extends StatelessWidget {
  final int count;
  const _CompareHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compare & verify',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _P.ink,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            count > 0
                ? '$count events tracked · live'
                : 'Ground truth analysis',
            style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
          ),
        ],
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasAnchor;
  const _EmptyState({this.hasAnchor = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows, size: 48, color: _P.inkTertiary),
            const SizedBox(height: 12),
            Text(
              hasAnchor ? 'No related reports yet' : 'No events to compare yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _P.inkSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasAnchor
                  ? 'No other reports cover this topic yet.\nCheck back as more come in.'
                  : 'Events appear once two or more sources cover\nthe same category on the same day.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
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

// ── Featured item (anchor) ────────────────────────────────────────────────────

class _FeaturedItemCard extends ConsumerStatefulWidget {
  final NewsItem item;
  const _FeaturedItemCard({required this.item});

  @override
  ConsumerState<_FeaturedItemCard> createState() => _FeaturedItemCardState();
}

class _FeaturedItemCardState extends ConsumerState<_FeaturedItemCard> {
  bool _votePending = false;

  Future<void> _castVote(String type) async {
    if (_votePending) return;
    setState(() => _votePending = true);
    try {
      await ref
          .read(compareNotifierProvider.notifier)
          .castVote(widget.item.id, type);
      ref.invalidate(voteProvider(widget.item.id));
    } catch (_) {
      // swallow — button re-enables via finally
    } finally {
      if (mounted) setState(() => _votePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCitizen = item.source == NewsSource.citizen;
    final userVote = isCitizen
        ? ref
              .watch(voteProvider(item.id))
              .when(data: (v) => v, loading: () => null, error: (e, s) => null)
        : null;
    final confirmCount = isCitizen
        ? ref
              .watch(voteCountsProvider(item.id))
              .when(
                data: (c) => c.confirm,
                loading: () => item.confirmCount,
                error: (e, s) => item.confirmCount,
              )
        : item.confirmCount;
    final disputeCount = isCitizen
        ? ref
              .watch(voteCountsProvider(item.id))
              .when(
                data: (c) => c.dispute,
                loading: () => item.disputeCount,
                error: (e, s) => item.disputeCount,
              )
        : item.disputeCount;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _P.navy.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'COMPARING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _P.navy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (item.category != null) ...[
                      _CategoryBadge(category: item.category!),
                      const SizedBox(width: 6),
                    ],
                    _SourceChip(source: item.source),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                    height: 1.35,
                  ),
                ),
                if (item.body != null && item.body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _P.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _timeAgo(item.publishedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _P.inkTertiary,
                      ),
                    ),
                    if (isCitizen) ...[
                      const SizedBox(width: 12),
                      _ActionBtn(
                        icon: userVote == 'confirm'
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        count: confirmCount,
                        active: userVote == 'confirm',
                        activeColor: _P.verified,
                        onTap: _votePending ? null : () => _castVote('confirm'),
                      ),
                      const SizedBox(width: 12),
                      _ActionBtn(
                        icon: userVote == 'dispute'
                            ? Icons.flag
                            : Icons.flag_outlined,
                        count: disputeCount,
                        active: userVote == 'dispute',
                        activeColor: _P.disputed,
                        onTap: _votePending ? null : () => _castVote('dispute'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Related reports header ────────────────────────────────────────────────────

class _RelatedReportsHeader extends StatelessWidget {
  final int count;
  const _RelatedReportsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          const Text(
            'Related reports',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              letterSpacing: -0.2,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _P.navy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _P.navy,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Cluster list ──────────────────────────────────────────────────────────────

class _ClusterList extends StatelessWidget {
  final List<EventCluster> clusters;
  const _ClusterList({required this.clusters});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: clusters.length,
      itemBuilder: (_, i) => _EventClusterCard(cluster: clusters[i]),
    );
  }
}

// ── Event cluster card ────────────────────────────────────────────────────────

class _EventClusterCard extends StatelessWidget {
  final EventCluster cluster;
  const _EventClusterCard({required this.cluster});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _P.card,
            borderRadius: BorderRadius.circular(16),
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
              _ClusterHeader(cluster: cluster),
              const Divider(height: 1, color: Color(0xFFE9ECEF)),
              _ClusterTimeline(items: cluster.items),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cluster header ────────────────────────────────────────────────────────────

class _ClusterHeader extends StatelessWidget {
  final EventCluster cluster;
  const _ClusterHeader({required this.cluster});

  @override
  Widget build(BuildContext context) {
    final total = cluster.supportCount + cluster.contradictCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(category: cluster.category),
              const Spacer(),
              Text(
                _formatDate(cluster.date),
                style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_categoryLabel(cluster.category)} · ${cluster.items.length} sources',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cluster.supportCount > cluster.contradictCount
                      ? _P.verified
                      : cluster.contradictCount > 0
                      ? _P.disputed
                      : _P.unverifiedFg,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${cluster.supportCount} supporting · ${cluster.contradictCount} contested',
                style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            _ConsensusMeter(
              supports: cluster.supportCount,
              contradicts: cluster.contradictCount,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Consensus meter ───────────────────────────────────────────────────────────

class _ConsensusMeter extends StatelessWidget {
  final int supports;
  final int contradicts;
  const _ConsensusMeter({required this.supports, required this.contradicts});

  @override
  Widget build(BuildContext context) {
    final total = supports + contradicts;
    if (total == 0) return const SizedBox.shrink();

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(height: 4, child: _buildBar()),
    );
    return bar;
  }

  Widget _buildBar() {
    if (contradicts == 0) return Container(color: _P.verified);
    if (supports == 0) return Container(color: _P.disputed);
    final supportFlex = ((supports / (supports + contradicts)) * 100).round();
    return Row(
      children: [
        Expanded(
          flex: supportFlex,
          child: Container(color: _P.verified),
        ),
        Expanded(
          flex: 100 - supportFlex,
          child: Container(color: _P.disputed),
        ),
      ],
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _ClusterTimeline extends StatelessWidget {
  final List<ClusterItem> items;
  const _ClusterTimeline({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            _TimelineRow(item: items[i], isLast: i == items.length - 1),
        ],
      ),
    );
  }
}

class _TimelineRow extends ConsumerStatefulWidget {
  final ClusterItem item;
  final bool isLast;
  const _TimelineRow({required this.item, required this.isLast});

  @override
  ConsumerState<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends ConsumerState<_TimelineRow> {
  bool _votePending = false;

  Future<void> _castVote(String type) async {
    if (_votePending) return;
    setState(() => _votePending = true);
    try {
      await ref
          .read(compareNotifierProvider.notifier)
          .castVote(widget.item.id, type);
      ref.invalidate(voteProvider(widget.item.id));
    } catch (_) {
      // swallow — button re-enables via finally
    } finally {
      if (mounted) setState(() => _votePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dotColor = switch (item.eval) {
      EvidenceEval.supports => _P.verified,
      EvidenceEval.contradicts => _P.disputed,
      EvidenceEval.unverified => _P.unverifiedFg,
    };

    final isCitizen = item.source == NewsSource.citizen;
    final userVote = isCitizen
        ? ref
              .watch(voteProvider(item.id))
              .when(data: (v) => v, loading: () => null, error: (e, s) => null)
        : null;
    final confirmCount = isCitizen
        ? ref
              .watch(voteCountsProvider(item.id))
              .when(
                data: (c) => c.confirm,
                loading: () => item.confirmCount,
                error: (e, s) => item.confirmCount,
              )
        : item.confirmCount;
    final disputeCount = isCitizen
        ? ref
              .watch(voteCountsProvider(item.id))
              .when(
                data: (c) => c.dispute,
                loading: () => item.disputeCount,
                error: (e, s) => item.disputeCount,
              )
        : item.disputeCount;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text(
                  _formatTime(item.publishedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: _P.inkTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (!widget.isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 1, color: _P.hairline),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _EvalBadge(eval: item.eval),
                      const SizedBox(width: 6),
                      _SourceChip(source: item.source),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _P.ink,
                      height: 1.35,
                    ),
                  ),
                  if (isCitizen) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ActionBtn(
                          icon: userVote == 'confirm'
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          count: confirmCount,
                          active: userVote == 'confirm',
                          activeColor: _P.verified,
                          onTap: _votePending
                              ? null
                              : () => _castVote('confirm'),
                        ),
                        const SizedBox(width: 12),
                        _ActionBtn(
                          icon: userVote == 'dispute'
                              ? Icons.flag
                              : Icons.flag_outlined,
                          count: disputeCount,
                          active: userVote == 'dispute',
                          activeColor: _P.disputed,
                          onTap: _votePending
                              ? null
                              : () => _castVote('dispute'),
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
    );
  }
}

// ── Badges & chips ────────────────────────────────────────────────────────────

class _EvalBadge extends StatelessWidget {
  final EvidenceEval eval;
  const _EvalBadge({required this.eval});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (eval) {
      EvidenceEval.supports => ('SUPPORTS', _P.verifiedSoft, _P.verified),
      EvidenceEval.contradicts => ('CONTRADICTS', _P.disputedSoft, _P.disputed),
      EvidenceEval.unverified => (
        'UNVERIFIED',
        _P.unverifiedBg,
        _P.unverifiedFg,
      ),
    };
    return _Chip(label: label, bgColor: bg, textColor: fg);
  }
}

class _SourceChip extends StatelessWidget {
  final NewsSource source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final isWire = source == NewsSource.wire;
    return _Chip(
      label: isWire ? 'WIRE' : 'CITIZEN',
      bgColor: isWire ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
      textColor: isWire ? _P.navy : const Color(0xFFB54708),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Chip({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _categoryLabel(category).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Vote button ───────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    this.count,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? _P.navy) : _P.inkTertiary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        child: count != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _effectiveCategory(NewsItem item) {
  if (item.category != null) return item.category!;
  const knownCategories = {'combat', 'aid', 'alert', 'displaced', 'infra'};
  for (final t in item.themes) {
    if (knownCategories.contains(t)) return t;
  }
  return 'other';
}

Color _categoryColor(String category) => switch (category) {
  'combat' => AppColors.reportCatCombat,
  'aid' => AppColors.reportCatAid,
  'alert' => AppColors.reportCatAlert,
  'displaced' => AppColors.reportCatDisplaced,
  'infra' => AppColors.reportCatInfra,
  _ => AppColors.reportCatOther,
};

String _categoryLabel(String category) => switch (category) {
  'combat' => 'Combat',
  'aid' => 'Aid',
  'alert' => 'Alert',
  'displaced' => 'Displaced',
  'infra' => 'Infrastructure',
  _ => category[0].toUpperCase() + category.substring(1),
};

String _formatDate(DateTime dt) {
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
  return '${months[dt.month - 1]} ${dt.day}';
}

String _formatTime(DateTime dt) {
  final h = dt.toLocal().hour.toString().padLeft(2, '0');
  final m = dt.toLocal().minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays}d ago';
}
