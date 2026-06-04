import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../alerts/presentation/providers/alert_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
const _infraTeal = Color(0xFF0891B2);
const _otherGrey = Color(0xFF9CA3AF);
const _surfaceGrey = Color(0xFFF7F8FA);

const _categoryColors = {
  MapCategory.combat: _combatRed,
  MapCategory.aid: _aidGreen,
  MapCategory.alert: _alertAmber,
  MapCategory.displaced: _displacedBlue,
  MapCategory.infra: _infraTeal,
  MapCategory.other: _otherGrey,
  MapCategory.all: Color(0xFF6B7280),
};

const _categoryIcons = {
  MapCategory.combat: Icons.radar,
  MapCategory.aid: Icons.favorite,
  MapCategory.alert: Icons.notifications_active,
  MapCategory.displaced: Icons.directions_run,
  MapCategory.infra: Icons.construction,
  MapCategory.other: Icons.more_horiz,
  MapCategory.all: Icons.circle,
};

const _categoryChips = [
  (label: 'All', category: MapCategory.all),
  (label: 'Combat / strike', category: MapCategory.combat),
  (label: 'Humanitarian aid', category: MapCategory.aid),
  (label: 'Air alert / siren', category: MapCategory.alert),
  (label: 'Displaced persons', category: MapCategory.displaced),
  (label: 'Infrastructure', category: MapCategory.infra),
  (label: 'Other', category: MapCategory.other),
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

Duration _durationFor(MapTimeRange range) => switch (range) {
  MapTimeRange.hour => const Duration(hours: 1),
  MapTimeRange.sixHours => const Duration(hours: 6),
  MapTimeRange.day => const Duration(hours: 24),
  MapTimeRange.all => Duration.zero,
};

List<MapReport> _applyFilters(List<MapReport> reports, MapFilters filters) {
  final now = DateTime.now();
  return reports.where((r) {
    if (filters.timeRange != MapTimeRange.all) {
      final cutoff = now.subtract(_durationFor(filters.timeRange));
      if (r.createdAt.isBefore(cutoff)) return false;
    }
    if (filters.category != MapCategory.all) {
      if (r.category != filters.category.name) return false;
    }
    return true;
  }).toList();
}

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
    final filteredReports = _applyFilters(state.reports, state.filters);
    final clusters = _computeClusters(filteredReports);

    final mapHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(state, notifier),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LiveBar(reports: filteredReports, filters: state.filters),
            if (state.showFiltersPanel)
              _FiltersPanel(state: state, notifier: notifier),
            _CategoryChipsRow(state: state, notifier: notifier),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                height: mapHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                      if (state.error != null)
                        _ErrorBanner(error: state.error!),
                    ],
                  ),
                ),
              ),
            ),
            if (state.selectedReport != null)
              _PinDetailsCard(
                report: state.selectedReport!,
                clusterReports: filteredReports
                    .where(
                      (r) =>
                          r.locationLabel ==
                          state.selectedReport!.locationLabel,
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
      ),
    );
  }

  AppBar _buildAppBar(MapState state, MapNotifier notifier) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
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
          icon: state.showUserMarker ? Icons.gps_fixed : Icons.gps_not_fixed,
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final ctrl = _mapController;
            final rd = ref.read;
            await notifier.locateMe();
            if (!mounted) return;
            final newState = rd(mapNotifierProvider);
            if (newState.showUserMarker && newState.userLocation != null) {
              ctrl.move(newState.userLocation!, 7.0);
              _showToast(
                messenger,
                'Centered on your area · ${newState.locationCity}',
              );
            } else if (!newState.showUserMarker &&
                newState.userLocation == null) {
              _showToast(messenger, 'Location marker hidden');
            } else {
              _showToast(messenger, 'Location unavailable');
            }
          },
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

  void _showToast(ScaffoldMessengerState messenger, String message) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.my_location, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      ),
    );
  }

  void _showSeeAllSheet(BuildContext context, MapState state) {
    final selected = state.selectedReport;
    if (selected == null) return;
    final clusterReports = state.reports
        .where((r) => r.locationLabel == selected.locationLabel)
        .toList();
    final category = MapCategory.values.firstWhere(
      (c) => c.name == selected.category,
      orElse: () => MapCategory.all,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeeAllSheet(
        locationLabel: selected.locationLabel,
        reports: clusterReports,
        category: category,
      ),
    );
  }

  void _showSetAlertSheet(BuildContext context, MapState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SetAlertSheet(
        locationLabel: state.selectedReport?.locationLabel ?? '',
        lat: state.selectedReport?.lat ?? 0,
        lng: state.selectedReport?.lng ?? 0,
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
          color: selected ? _navy : Colors.grey.shade100,
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
            color: selected ? const Color(0xFF1A1A2E) : Colors.grey.shade100,
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
          color: selected ? const Color(0xFF1A1A2E) : Colors.grey.shade100,
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
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
          if (state.showUserMarker && state.userLocation != null)
            MarkerLayer(markers: [_buildUserMarker(state.userLocation!)]),
        ],
      ),
    );
  }

  Marker _buildUserMarker(LatLng position) => Marker(
    point: position,
    width: 120,
    height: 56,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "You are here" label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'You are here',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 3),
        // Blue pulsing dot
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

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
    final label = _chipLabel(category);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.locationLabel,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$label · $count events in last 24h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Report preview card ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceGrey,
                borderRadius: BorderRadius.circular(12),
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
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.6,
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
                  const SizedBox(height: 8),
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.locationLabel} · Unverified citizen submission',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Action buttons ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: const Text(
                      'See all',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: onSeeAll,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(
                      Icons.notifications_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Set alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'RECENT ACTIVITY',
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
          ...List.generate(
            recent.length,
            (i) => Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                i < recent.length - 1 ? 8 : 16,
              ),
              child: _RecentActivityCard(
                cluster: recent[i],
                onTap: () => onTap(recent[i]),
              ),
            ),
          ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cluster.locationLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chipLabel,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cluster.count} events',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
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
  final MapCategory category;

  const _SeeAllSheet({
    required this.locationLabel,
    required this.reports,
    required this.category,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[category] ?? Colors.grey;
    final icon = _categoryIcons[category] ?? Icons.circle;
    final categoryLabel = _categoryChips
        .firstWhere(
          (c) => c.category == category,
          orElse: () => (label: 'Other', category: MapCategory.all),
        )
        .label;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ───────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Row(
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
                        locationLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reports.length} events · $categoryLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          // ── Report list ───────────────────────────────────────────
          Expanded(
            child: reports.isEmpty
                ? const Center(child: Text('No events found'))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: reports.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = reports[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surfaceGrey,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail placeholder
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 72,
                                height: 72,
                                color: color.withValues(alpha: 0.15),
                                child: Icon(
                                  icon,
                                  color: color.withValues(alpha: 0.5),
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'CITIZEN REPORT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey.shade600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${_timeAgo(r.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                      height: 1.35,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
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

class _SetAlertSheet extends ConsumerStatefulWidget {
  final String locationLabel;
  final double lat;
  final double lng;

  const _SetAlertSheet({
    required this.locationLabel,
    required this.lat,
    required this.lng,
  });

  @override
  ConsumerState<_SetAlertSheet> createState() => _SetAlertSheetState();
}

class _SetAlertSheetState extends ConsumerState<_SetAlertSheet> {
  double _radiusKm = 5;
  bool _confirmed = false;
  final Map<MapCategory, bool> _toggles = {
    MapCategory.combat: true,
    MapCategory.aid: false,
    MapCategory.alert: true,
    MapCategory.displaced: false,
    MapCategory.infra: false,
    MapCategory.other: false,
  };

  static const _alertCategories = [
    (label: 'Combat / strike', category: MapCategory.combat),
    (label: 'Humanitarian aid', category: MapCategory.aid),
    (label: 'Air alert / siren', category: MapCategory.alert),
    (label: 'Displaced persons', category: MapCategory.displaced),
    (label: 'Infrastructure', category: MapCategory.infra),
    (label: 'Other', category: MapCategory.other),
  ];

  Widget _buildConfirmation(BuildContext context) {
    final enabledCount = _toggles.values.where((v) => v).length;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Drag handle ──────────────────────────────────────────────
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // ── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alert set',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You can change this anytime',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // ── Bell icon with glow ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _aidGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(
                Icons.notifications_active,
                color: _aidGreen,
                size: 40,
              ),
            ],
          ),
        ),
        // ── Confirmation text ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: "You'll be alerted about "),
                TextSpan(
                  text:
                      '$enabledCount event type${enabledCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const TextSpan(text: ' within '),
                TextSpan(
                  text: '${_radiusKm.round()}km',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                TextSpan(text: ' of ${widget.locationLabel}.'),
              ],
            ),
          ),
        ),
        SizedBox(height: 32 + bottom),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) return _buildConfirmation(context);
    // Watch for real save errors from the notifier.
    final alertState = ref.watch(alertNotifierProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Drag handle ─────────────────────────────────────────────
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // ── Header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: _navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert for ${widget.locationLabel}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get notified when something happens nearby',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // ── Notify me about ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'NOTIFY ME ABOUT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
        ),
        for (int i = 0; i < _alertCategories.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            _categoryColors[_alertCategories[i].category] ??
                            Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _categoryIcons[_alertCategories[i].category] ??
                            Icons.circle,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _alertCategories[i].label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _toggles[_alertCategories[i].category] ?? false,
                      activeTrackColor: _navy,
                      activeThumbColor: Colors.white,
                      onChanged: (v) => setState(
                        () => _toggles[_alertCategories[i].category] = v,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < _alertCategories.length - 1) const SizedBox(height: 8),
        ],
        // ── Radius ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            'RADIUS — ${_radiusKm.round()} KM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _navy,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: Colors.white,
            overlayColor: _navy.withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 2,
            ),
            trackHeight: 3,
          ),
          child: Slider(
            value: _radiusKm,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (v) => setState(() => _radiusKm = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 km',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                '20 km',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        // ── Button ──────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Turn on alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: alertState.status == AlertStatus.saving
                  ? null
                  : () async {
                      final enabledCategories = _toggles.entries
                          .where((e) => e.value)
                          .map((e) => e.key.name)
                          .toList();
                      // Read auth UID — falls back to 'anonymous' if not signed in.
                      final uid =
                          ref.read(authNotifierProvider).user?.uid ??
                          'anonymous';
                      await ref
                          .read(alertNotifierProvider.notifier)
                          .save(
                            userId: uid,
                            locationLabel: widget.locationLabel,
                            lat: widget.lat,
                            lng: widget.lng,
                            radiusKm: _radiusKm,
                            categories: enabledCategories,
                          );
                      if (mounted) setState(() => _confirmed = true);
                    },
            ),
          ),
        ),
      ],
    );
  }
}
