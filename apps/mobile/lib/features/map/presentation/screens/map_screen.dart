import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/map_report.dart';
import '../providers/map_provider.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

const _navy = Color(0xFF1E3A8A);
const _combatRed = Color(0xFFE53E3E);
const _aidGreen = Color(0xFF38A169);
const _alertAmber = Color(0xFFD97706);
const _displacedBlue = Color(0xFF3182CE);
const _diplomaticPurple = Color(0xFF805AD5);
const _surfaceGrey = Color(0xFFF7F8FA);

const _categoryColors = {
  MapCategory.combat: _combatRed,
  MapCategory.aid: _aidGreen,
  MapCategory.alert: _alertAmber,
  MapCategory.displaced: _displacedBlue,
  MapCategory.diplomatic: _diplomaticPurple,
  MapCategory.all: Color(0xFF6B7280),
};

const _categoryIcons = {
  MapCategory.combat: Icons.radar,
  MapCategory.aid: Icons.favorite,
  MapCategory.alert: Icons.notifications_active,
  MapCategory.displaced: Icons.directions_run,
  MapCategory.diplomatic: Icons.handshake_outlined,
  MapCategory.all: Icons.circle,
};

const _categoryChips = [
  (label: 'All', category: MapCategory.all),
  (label: 'Combat/strike', category: MapCategory.combat),
  (label: 'Humanitarian aid', category: MapCategory.aid),
  (label: 'Air alert/siren', category: MapCategory.alert),
  (label: 'Displaced persons', category: MapCategory.displaced),
  (label: 'Diplomatic', category: MapCategory.diplomatic),
];

// ---------------------------------------------------------------------------
// Location cluster (groups reports by city for map pins + activity cards)
// ---------------------------------------------------------------------------

class _LocationCluster {
  final String locationLabel;
  final double lat;
  final double lng;
  final int count;
  final MapCategory dominantCategory;
  final List<MapReport> reports;

  const _LocationCluster({
    required this.locationLabel,
    required this.lat,
    required this.lng,
    required this.count,
    required this.dominantCategory,
    required this.reports,
  });
}

List<_LocationCluster> _computeClusters(List<MapReport> reports) {
  final groups = <String, List<MapReport>>{};
  for (final r in reports) {
    groups.putIfAbsent(r.locationLabel, () => []).add(r);
  }
  return groups.entries.map((e) {
    final list = e.value;
    final counts = <MapCategory, int>{};
    for (final r in list) {
      final cat = MapCategory.values.firstWhere(
        (c) => c.name == r.category,
        orElse: () => MapCategory.all,
      );
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    final dominant = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return _LocationCluster(
      locationLabel: e.key,
      lat: list.first.lat,
      lng: list.first.lng,
      count: list.length,
      dominantCategory: dominant,
      reports: list,
    );
  }).toList()..sort((a, b) => b.count.compareTo(a.count));
}

String _timeRangeLabel(MapTimeRange range) => switch (range) {
  MapTimeRange.hour => 'last hour',
  MapTimeRange.sixHours => 'last 6 hours',
  MapTimeRange.day => 'last 24 hours',
  MapTimeRange.all => 'all time',
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Kick off the initial data load centred on Ukraine
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapNotifierProvider.notifier).watchArea(49.0, 31.5, 600);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final clusters = _computeClusters(state.reports);

    return Scaffold(
      backgroundColor: _surfaceGrey,
      appBar: _buildAppBar(state, notifier),
      body: Column(
        children: [
          _LiveBar(reports: state.reports, filters: state.filters),
          if (state.showFiltersPanel)
            _FiltersPanel(state: state, notifier: notifier),
          _CategoryChipsRow(state: state, notifier: notifier),
          Expanded(
            child: Stack(
              children: [
                _MapCanvas(
                  state: state,
                  mapController: _mapController,
                  clusters: clusters,
                  onClusterTap: (cluster) {
                    if (cluster.reports.isNotEmpty) {
                      notifier.selectPin(cluster.reports.first);
                    }
                  },
                ),
                if (state.isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (state.error != null) _ErrorBanner(error: state.error!),
              ],
            ),
          ),
          if (state.selectedReport != null)
            _PinDetailsCard(
              report: state.selectedReport!,
              clusterReports: state.reports
                  .where(
                    (r) =>
                        r.locationLabel == state.selectedReport!.locationLabel,
                  )
                  .toList(),
              onClose: notifier.deselectPin,
              onSeeAll: () => _showSeeAllSheet(context, state),
              onSetAlert: () => _showSetAlertSheet(context, state),
            )
          else
            _RecentActivitySection(
              clusters: clusters,
              onTap: (cluster) {
                if (cluster.reports.isNotEmpty) {
                  notifier.selectPin(cluster.reports.first);
                }
              },
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(MapState state, MapNotifier notifier) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _navy,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Live map',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
      actions: [
        _CircularIconButton(
          icon: Icons.gps_fixed,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Locating… (never uploaded)'),
              duration: Duration(seconds: 2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _FilterButtonWithBadge(state: state, notifier: notifier),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
    );
  }

  void _showSeeAllSheet(BuildContext context, MapState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeeAllSheet(
        locationLabel: state.selectedReport?.locationLabel ?? '',
        reports: state.reports
            .where(
              (r) => r.locationLabel == state.selectedReport?.locationLabel,
            )
            .toList(),
      ),
    );
  }

  void _showSetAlertSheet(BuildContext context, MapState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SetAlertSheet(
        locationLabel: state.selectedReport?.locationLabel ?? '',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Circular icon button (AppBar action)
// ---------------------------------------------------------------------------

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircularIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          color: Colors.white,
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF374151)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter button with active badge
// ---------------------------------------------------------------------------

class _FilterButtonWithBadge extends StatelessWidget {
  final MapState state;
  final MapNotifier notifier;

  const _FilterButtonWithBadge({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: notifier.toggleFiltersPanel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              color: state.showFiltersPanel
                  ? _navy.withValues(alpha: 0.08)
                  : Colors.white,
            ),
            child: Icon(
              Icons.filter_list,
              size: 18,
              color: state.showFiltersPanel ? _navy : const Color(0xFF374151),
            ),
          ),
          if (!state.filters.isDefault)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                key: const Key('filter_active_badge'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _combatRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LIVE status bar
// ---------------------------------------------------------------------------

class _LiveBar extends StatelessWidget {
  final List<MapReport> reports;
  final MapFilters filters;

  const _LiveBar({required this.reports, required this.filters});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _combatRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: _combatRed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${reports.length} events · ${_timeRangeLabel(filters.timeRange)}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filters panel (collapsible card)
// ---------------------------------------------------------------------------

class _FiltersPanel extends StatelessWidget {
  final MapState state;
  final MapNotifier notifier;

  const _FiltersPanel({required this.state, required this.notifier});

  static const _timeRanges = [
    (label: 'Last hour', range: MapTimeRange.hour),
    (label: '6 hours', range: MapTimeRange.sixHours),
    (label: '24 hours', range: MapTimeRange.day),
    (label: 'All time', range: MapTimeRange.all),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'MAP FILTERS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: notifier.resetFilters,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Time range ─────────────────────────────────────────
            Text(
              'TIME RANGE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            // 4 equal-width segmented buttons
            Row(
              children: List.generate(_timeRanges.length, (i) {
                final item = _timeRanges[i];
                final selected = state.filters.timeRange == item.range;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                    child: _TimeRangeButton(
                      label: item.label,
                      selected: selected,
                      onTap: () => notifier.updateFilters(
                        state.filters.copyWith(timeRange: item.range),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // ── Show city labels ───────────────────────────────────
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Show city labels',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: state.showCityLabels,
                  activeThumbColor: Colors.white,
                  activeTrackColor: _navy,
                  onChanged: (_) => notifier.toggleCityLabels(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRangeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeRangeButton({
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
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _navy : Colors.white,
          border: Border.all(color: selected ? _navy : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chips row
// ---------------------------------------------------------------------------

class _CategoryChipsRow extends StatelessWidget {
  final MapState state;
  final MapNotifier notifier;

  const _CategoryChipsRow({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: _categoryChips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryChipWidget(
                    label: chip.label,
                    category: chip.category,
                    selected: state.filters.category == chip.category,
                    onTap: () => notifier.updateFilters(
                      state.filters.copyWith(category: chip.category),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CategoryChipWidget extends StatelessWidget {
  final String label;
  final MapCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChipWidget({
    required this.label,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (category == MapCategory.all) {
      // "All" — solid dark pill when selected
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A1A2E) : Colors.transparent,
            border: Border.all(
              color: selected ? Colors.transparent : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    // Other categories — dot + label
    final dotColor = _categoryColors[category] ?? Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? dotColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(color: selected ? dotColor : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF111827)
                    : Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map canvas
// ---------------------------------------------------------------------------

const _ukraineCenter = LatLng(49.0, 31.5);
const _defaultZoom = 5.8;

class _MapCanvas extends StatelessWidget {
  final MapState state;
  final MapController mapController;
  final List<_LocationCluster> clusters;
  final void Function(_LocationCluster) onClusterTap;

  const _MapCanvas({
    required this.state,
    required this.mapController,
    required this.clusters,
    required this.onClusterTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: FlutterMap(
        mapController: mapController,
        options: const MapOptions(
          initialCenter: _ukraineCenter,
          initialZoom: _defaultZoom,
          interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            // Same tile source as the report screen (step_location.dart)
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.frontline.app',
            maxZoom: 18,
          ),
          MarkerLayer(
            markers: clusters.map((c) => _buildClusterMarker(c)).toList(),
          ),
        ],
      ),
    );
  }

  Marker _buildClusterMarker(_LocationCluster cluster) {
    final isSelected =
        state.selectedReport?.locationLabel == cluster.locationLabel;
    final size = isSelected ? 52.0 : 44.0;

    return Marker(
      point: LatLng(cluster.lat, cluster.lng),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => onClusterTap(cluster),
        child: _ClusterMarkerWidget(cluster: cluster, isSelected: isSelected),
      ),
    );
  }
}

class _ClusterMarkerWidget extends StatelessWidget {
  final _LocationCluster cluster;
  final bool isSelected;

  const _ClusterMarkerWidget({required this.cluster, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[cluster.dominantCategory] ?? Colors.grey;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring (visible when recent or selected)
        if (isSelected)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        // Inner pin circle with count
        Container(
          width: isSelected ? 40 : 36,
          height: isSelected ? 40 : 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${cluster.count}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pin details card (selected state)
// ---------------------------------------------------------------------------

class _PinDetailsCard extends StatelessWidget {
  final MapReport report;
  final List<MapReport> clusterReports;
  final VoidCallback onClose;
  final VoidCallback onSeeAll;
  final VoidCallback onSetAlert;

  const _PinDetailsCard({
    required this.report,
    required this.clusterReports,
    required this.onClose,
    required this.onSeeAll,
    required this.onSetAlert,
  });

  @override
  Widget build(BuildContext context) {
    final category = MapCategory.values.firstWhere(
      (c) => c.name == report.category,
      orElse: () => MapCategory.all,
    );
    final color = _categoryColors[category] ?? Colors.grey;
    final icon = _categoryIcons[category] ?? Icons.circle;
    final count = clusterReports.length;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.locationLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '${_chipLabel(category)} · $count events in last 24h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Report preview card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _combatRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CITIZEN REPORT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(report.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.list, size: 16),
                    label: const Text('See all'),
                    onPressed: onSeeAll,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(
                      Icons.notifications_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Set alert',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: onSetAlert,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _chipLabel(MapCategory cat) => _categoryChips
      .firstWhere(
        (c) => c.category == cat,
        orElse: () => (label: 'Other', category: MapCategory.all),
      )
      .label;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Recent activity section (no pin selected)
// ---------------------------------------------------------------------------

class _RecentActivitySection extends StatelessWidget {
  final List<_LocationCluster> clusters;
  final void Function(_LocationCluster) onTap;

  const _RecentActivitySection({required this.clusters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final recent = clusters.take(5).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      color: _surfaceGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'Recent activity',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No events in this area',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: recent.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _RecentActivityCard(
                  cluster: recent[i],
                  onTap: () => onTap(recent[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final _LocationCluster cluster;
  final VoidCallback onTap;

  const _RecentActivityCard({required this.cluster, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[cluster.dominantCategory] ?? Colors.grey;
    final icon = _categoryIcons[cluster.dominantCategory] ?? Icons.circle;
    final chipLabel = _categoryChips
        .firstWhere(
          (c) => c.category == cluster.dominantCategory,
          orElse: () => (label: 'Other', category: MapCategory.all),
        )
        .label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cluster.locationLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    chipLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cluster.count} events',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        color: _combatRed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          error,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// See all sheet
// ---------------------------------------------------------------------------

class _SeeAllSheet extends StatelessWidget {
  final String locationLabel;
  final List<MapReport> reports;

  const _SeeAllSheet({required this.locationLabel, required this.reports});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  'Events in $locationLabel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: reports.isEmpty
                ? const Center(child: Text('No events found'))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(12),
                    itemCount: reports.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = reports[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surfaceGrey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.locationLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusChip(status: r.status),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set alert sheet
// ---------------------------------------------------------------------------

class _SetAlertSheet extends StatefulWidget {
  final String locationLabel;
  const _SetAlertSheet({required this.locationLabel});

  @override
  State<_SetAlertSheet> createState() => _SetAlertSheetState();
}

class _SetAlertSheetState extends State<_SetAlertSheet> {
  double _radiusKm = 10;
  final Set<MapCategory> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Alert for ${widget.locationLabel}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Radius'),
              Text(
                '${_radiusKm.round()} km',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 20,
            divisions: 19,
            activeColor: _navy,
            onChanged: (v) => setState(() => _radiusKm = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Event types',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _categoryChips
                .where((c) => c.category != MapCategory.all)
                .map(
                  (c) => FilterChip(
                    label: Text(c.label, style: const TextStyle(fontSize: 12)),
                    selected: _selected.contains(c.category),
                    selectedColor: (_categoryColors[c.category] ?? Colors.grey)
                        .withValues(alpha: 0.15),
                    onSelected: (v) => setState(
                      () => v
                          ? _selected.add(c.category)
                          : _selected.remove(c.category),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              label: const Text(
                'Turn on alerts',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Alert saved')));
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'verified' => ('Verified', const Color(0xFF1F7A3F)),
      'disputed' => ('Disputed', _combatRed),
      _ => ('Pending', const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
