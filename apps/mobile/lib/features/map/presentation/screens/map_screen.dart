import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../alerts/presentation/providers/alert_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/map_report.dart';
import '../providers/map_provider.dart';

part 'map_screen_bottom.dart';

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
    // Move the map and reload reports when geocoding resolves a new location.
    ref.listen<LatLng?>(mapNotifierProvider.select((s) => s.searchedLocation), (
      _,
      location,
    ) {
      if (location == null) return;
      _mapController.move(location, 12.0);
      ref
          .read(mapNotifierProvider.notifier)
          .watchArea(location.latitude, location.longitude, 300);
    });
    // Show a snackbar when a location search yields no results.
    ref.listen<String?>(mapNotifierProvider.select((s) => s.searchError), (
      _,
      err,
    ) {
      if (err == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: _combatRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          ),
        );
    });

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
              ctrl.move(newState.userLocation!, 10.0);
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
        preferredSize: const Size.fromHeight(57),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _MapSearchBar(state: state, notifier: notifier),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
          ],
        ),
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
// Search bar (AppBar bottom)
// ---------------------------------------------------------------------------

class _MapSearchBar extends StatefulWidget {
  final MapState state;
  final MapNotifier notifier;

  const _MapSearchBar({required this.state, required this.notifier});

  @override
  State<_MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<_MapSearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => widget.notifier.searchLocation(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: 'Search location...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
        suffixIcon: widget.state.isSearching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                ),
              )
            : _ctrl.text.isNotEmpty
            ? IconButton(
                key: const Key('mapSearchClearButton'),
                icon: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                onPressed: () => setState(() => _ctrl.clear()),
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _navy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        isDense: true,
      ),
    );
  }
}

// (Pin details card, Recent activity, Error banner, See-all sheet and
//  Set-alert sheet live in map_screen_bottom.dart via `part of`.)
