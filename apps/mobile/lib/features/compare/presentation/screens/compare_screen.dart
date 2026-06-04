import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../../domain/entities/event_cluster.dart';
import '../providers/compare_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kMaxWidth = 700.0;

class _P {
  static const background = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const eventCardBg = Color(0xFFEEF2FF);
  static const navy = AppColors.reportNavy;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const verified = AppColors.reportVerified;
  static const verifiedSoft = AppColors.reportVerifiedSoft;
  static const disputed = AppColors.reportDisputed;
  static const disputedSoft = Color(0xFFFEE2E2);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFEF3C7);
  static const unverifiedFg = Color(0xFF6B7280);
  static const unverifiedBg = Color(0xFFF3F4F6);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CompareScreen extends ConsumerStatefulWidget {
  final NewsItem? anchorItem;
  const CompareScreen({super.key, this.anchorItem});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  int _selectedIndex = 0;
  String? _activeSourceFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preselectTab());
  }

  void _preselectTab() {
    final anchor = widget.anchorItem;
    if (anchor == null) return;
    final clusters = ref.read(compareNotifierProvider).clusters;
    final targetCat = _effectiveCategory(anchor);
    final idx = clusters.indexWhere((c) => c.category == targetCat);
    if (idx >= 0 && mounted) {
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compareNotifierProvider);
    final anchor = widget.anchorItem;
    final clusters = state.clusters;

    return ColoredBox(
      color: _P.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppBar(onBack: anchor != null ? () => context.pop() : null),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'One event. Multiple sources. See how a citizen report lines up with — or contradicts — major outlets.',
                style: TextStyle(
                  fontSize: 12,
                  color: _P.inkTertiary,
                  height: 1.5,
                ),
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _P.navy),
                    )
                  : state.error != null
                  ? _ErrorState(error: state.error!)
                  : clusters.isEmpty
                  ? const _EmptyState()
                  : _CompareBody(
                      clusters: clusters,
                      selectedIndex: _selectedIndex,
                      activeSourceFilter: _activeSourceFilter,
                      onTabSelected: (i) => setState(() {
                        _selectedIndex = i;
                        _activeSourceFilter = null;
                      }),
                      onSourceFilterChanged: (f) =>
                          setState(() => _activeSourceFilter = f),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final VoidCallback? onBack;
  const _AppBar({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios, size: 16, color: _P.ink),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          else
            IconButton(
              onPressed: null,
              icon: const Icon(Icons.shuffle, size: 18, color: _P.navy),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(width: 4),
          const Text(
            'Side by side',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: null,
            icon: const Icon(
              Icons.help_outline,
              size: 18,
              color: _P.inkTertiary,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.compare_arrows, size: 48, color: _P.inkTertiary),
            SizedBox(height: 12),
            Text(
              'No events to compare yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _P.inkSecondary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Events appear once two or more sources cover\nthe same category on the same day.',
              textAlign: TextAlign.center,
              style: TextStyle(
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

// ── Compare body (tab pills + event card + timeline) ──────────────────────────

class _CompareBody extends StatelessWidget {
  final List<EventCluster> clusters;
  final int selectedIndex;
  final String? activeSourceFilter;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<String?> onSourceFilterChanged;

  const _CompareBody({
    required this.clusters,
    required this.selectedIndex,
    required this.activeSourceFilter,
    required this.onTabSelected,
    required this.onSourceFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedIndex.clamp(0, clusters.length - 1);
    final cluster = clusters[safeIndex];
    final filtered = activeSourceFilter == null
        ? cluster.items
        : cluster.items.where((i) {
            if (activeSourceFilter == 'citizen') {
              return i.source == NewsSource.citizen;
            }
            return i.sourceName == activeSourceFilter;
          }).toList();

    return CustomScrollView(
      slivers: [
        // Tab pills row
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: clusters.length,
              separatorBuilder: (context0, index0) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = clusters[i];
                final selected = i == safeIndex;
                final dotColor = _clusterStatusColor(c);
                return GestureDetector(
                  onTap: () => onTabSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _P.navy : _P.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? _P.navy : _P.hairline,
                        width: selected ? 0 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? Colors.white70 : dotColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            _eventName(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : _P.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        // Event card
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              child: _EventCard(
                cluster: cluster,
                activeSourceFilter: activeSourceFilter,
                onSourceFilterChanged: onSourceFilterChanged,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        // Timeline section label
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: const [
                Text(
                  'REPORT TIMELINE · CHRONOLOGICAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _P.inkTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Timeline entries
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final first = filtered.first.publishedAt;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxWidth),
                  child: _TimelineEntry(
                    item: filtered[i],
                    first: first,
                    isLast: i == filtered.length - 1,
                  ),
                ),
              );
            }, childCount: filtered.length),
          ),
        ),
      ],
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventCluster cluster;
  final String? activeSourceFilter;
  final ValueChanged<String?> onSourceFilterChanged;

  const _EventCard({
    required this.cluster,
    required this.activeSourceFilter,
    required this.onSourceFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusFg, statusBg, statusIcon) = _clusterStatus(
      cluster,
    );
    final title = _eventName(cluster);
    final firstItem = cluster.items.isNotEmpty ? cluster.items.first : null;
    final advantage = _citizenAdvantage(cluster);
    final groups = _sourceGroups(cluster);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.eventCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12, color: statusFg),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _P.ink,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          ),
          if (firstItem != null) ...[
            const SizedBox(height: 8),
            // Meta row
            Row(
              children: [
                Icon(
                  _categoryIcon(cluster.category),
                  size: 13,
                  color: _categoryColor(cluster.category),
                ),
                const SizedBox(width: 4),
                Text(
                  _categoryLabel(cluster.category),
                  style: const TextStyle(fontSize: 12, color: _P.inkSecondary),
                ),
                const Text(
                  ' · ',
                  style: TextStyle(fontSize: 12, color: _P.inkTertiary),
                ),
                Text(
                  _formatDate(cluster.date),
                  style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Source filter label
          const Text(
            'REPORTED BY · TAP TO FILTER',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _P.inkTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Source chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: groups.map((g) {
              final isActive = activeSourceFilter == g.key;
              return GestureDetector(
                onTap: () => onSourceFilterChanged(isActive ? null : g.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _P.navy
                        : g.isCitizen
                        ? _P.amberSoft
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    g.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : g.isCitizen
                          ? const Color(0xFFB54708)
                          : _P.navy,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Citizen advantage insight
          if (advantage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _P.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 15, color: _P.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'A citizen reported this ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _P.inkSecondary,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: advantage,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(
                            text: ' before major outlets confirmed.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Source group model ────────────────────────────────────────────────────────

class _SourceGroup {
  final String key;
  final String label;
  final bool isCitizen;
  const _SourceGroup({
    required this.key,
    required this.label,
    required this.isCitizen,
  });
}

// ── Timeline entry ────────────────────────────────────────────────────────────

class _TimelineEntry extends StatelessWidget {
  final ClusterItem item;
  final DateTime first;
  final bool isLast;
  const _TimelineEntry({
    required this.item,
    required this.first,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final offset = item.publishedAt.difference(first);
    final isCitizen = item.source == NewsSource.citizen;
    final dotBorderColor = isCitizen ? _P.amber : _P.navy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: time + offset
          Row(
            children: [
              Text(
                _formatTime(item.publishedAt),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _P.inkSecondary,
                ),
              ),
              const Spacer(),
              if (offset.inMinutes > 0)
                Text(
                  _formatOffset(offset),
                  style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Dot + card row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: line + dot
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: dotBorderColor, width: 2),
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Center(
                            child: Container(width: 1, color: _P.hairline),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Card
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _P.card,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card header
                          Text(
                            _cardHeader(item),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _P.inkTertiary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Title
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _P.ink,
                              height: 1.35,
                            ),
                          ),
                          // Body excerpt
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
                        ],
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _effectiveCategory(NewsItem item) {
  if (item.category != null) return item.category!;
  const knownCategories = {'combat', 'aid', 'alert', 'displaced', 'infra'};
  for (final t in item.themes) {
    if (knownCategories.contains(t)) return t;
  }
  return 'other';
}

List<_SourceGroup> _sourceGroups(EventCluster cluster) {
  final groups = <_SourceGroup>[];
  final citizenCount = cluster.items
      .where((i) => i.source == NewsSource.citizen)
      .length;
  if (citizenCount > 0) {
    groups.add(
      _SourceGroup(
        key: 'citizen',
        label: 'Citizen report ×$citizenCount',
        isCitizen: true,
      ),
    );
  }
  final wireNames = <String>{};
  for (final i in cluster.items) {
    if (i.source == NewsSource.wire) {
      final name = i.sourceName;
      if (name != null && wireNames.add(name)) {
        groups.add(_SourceGroup(key: name, label: name, isCitizen: false));
      } else if (name == null && wireNames.add('__wire__')) {
        groups.add(
          const _SourceGroup(key: '__wire__', label: 'Wire', isCitizen: false),
        );
      }
    }
  }
  return groups;
}

(String, Color, Color, IconData) _clusterStatus(EventCluster cluster) {
  if (cluster.contradictCount > 0) {
    return ('SOURCES CONFLICT', _P.disputed, _P.disputedSoft, Icons.close);
  }
  if (cluster.supportCount >= 2) {
    return ('SOURCES ALIGN', _P.verified, _P.verifiedSoft, Icons.check);
  }
  return ('UNVERIFIED', _P.unverifiedFg, _P.unverifiedBg, Icons.help_outline);
}

Color _clusterStatusColor(EventCluster cluster) => _clusterStatus(cluster).$2;

String _eventName(EventCluster cluster) {
  final citizen = cluster.items
      .where((i) => i.source == NewsSource.citizen)
      .firstOrNull;
  if (citizen != null) return citizen.title;
  if (cluster.items.isNotEmpty) return cluster.items.first.title;
  return '${_categoryLabel(cluster.category)} · ${_formatDate(cluster.date)}';
}

String? _citizenAdvantage(EventCluster cluster) {
  final citizenItems =
      cluster.items.where((i) => i.source == NewsSource.citizen).toList()
        ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
  final wireItems =
      cluster.items.where((i) => i.source == NewsSource.wire).toList()
        ..sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
  if (citizenItems.isEmpty || wireItems.isEmpty) return null;
  final diff = wireItems.first.publishedAt.difference(
    citizenItems.first.publishedAt,
  );
  if (diff.inMinutes < 1) return null;
  return _formatOffset(diff);
}

String _reporterToken(String id) {
  final clean = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return '#${clean.substring(0, clean.length.clamp(0, 4))}';
}

String _formatOffset(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? '+${h}h ${m}m' : '+${h}h';
  }
  return '+${d.inMinutes}m';
}

String _cardHeader(ClusterItem item) {
  if (item.source == NewsSource.citizen) {
    final token = _reporterToken(item.id);
    return '● CITIZEN REPORT · Anonymous · token $token';
  }
  final name = item.sourceName;
  if (name != null && name.isNotEmpty) return '● WIRE · $name';
  return '● WIRE';
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

IconData _categoryIcon(String category) => switch (category) {
  'combat' => Icons.local_fire_department,
  'aid' => Icons.volunteer_activism,
  'alert' => Icons.warning_amber,
  'displaced' => Icons.people,
  'infra' => Icons.electrical_services,
  _ => Icons.circle,
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
