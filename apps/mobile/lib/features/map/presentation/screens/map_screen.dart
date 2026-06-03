import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/map_report.dart';
import '../providers/map_provider.dart';

// ---------------------------------------------------------------------------
// Category chip metadata
// ---------------------------------------------------------------------------

const _categoryChips = [
  (label: 'All', category: MapCategory.all),
  (label: 'Combat/strike', category: MapCategory.combat),
  (label: 'Humanitarian aid', category: MapCategory.aid),
  (label: 'Air alert/siren', category: MapCategory.alert),
  (label: 'Displaced persons', category: MapCategory.displaced),
  (label: 'Diplomatic', category: MapCategory.diplomatic),
];

const _categoryColors = {
  MapCategory.combat: Color(0xFFB42318),
  MapCategory.aid: Color(0xFF1F7A3F),
  MapCategory.alert: Color(0xFFB54708),
  MapCategory.displaced: Color(0xFF1E3A8A),
  MapCategory.diplomatic: Color(0xFF7C3AED),
  MapCategory.all: Color(0xFF374151),
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
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);

    return Scaffold(
      appBar: _buildAppBar(context, state, notifier),
      body: Column(
        children: [
          if (state.showFiltersPanel)
            _FiltersPanel(state: state, notifier: notifier),
          _CategoryChipsRow(state: state, notifier: notifier),
          Expanded(
            child: Stack(
              children: [
                _MapCanvas(
                  state: state,
                  mapController: _mapController,
                  onPinTap: notifier.selectPin,
                ),
                if (state.isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (state.error != null)
                  _ErrorBanner(error: state.error!),
              ],
            ),
          ),
          if (state.selectedReport != null)
            _PinDetailsCard(
              report: state.selectedReport!,
              onClose: notifier.deselectPin,
              onSeeAll: () => _showSeeAllSheet(context, state),
              onSetAlert: () => _showSetAlertSheet(context, state),
            )
          else
            _RecentActivitySection(
              reports: state.reports,
              onTap: notifier.selectPin,
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    MapState state,
    MapNotifier notifier,
  ) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          const Text('Live map', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFB42318),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${state.reports.length} events',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.gps_fixed),
          tooltip: 'My location',
          onPressed: () => _onMyLocationTapped(context),
        ),
        _FilterIconWithBadge(state: state, notifier: notifier),
        const SizedBox(width: 4),
      ],
    );
  }

  void _onMyLocationTapped(BuildContext context) {
    // Location is fetched but never uploaded per privacy rules.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Locating you… (never uploaded)')),
    );
  }

  void _showSeeAllSheet(BuildContext context, MapState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
      builder: (_) => _SetAlertSheet(
        locationLabel: state.selectedReport?.locationLabel ?? '',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar filter icon with active badge
// ---------------------------------------------------------------------------

class _FilterIconWithBadge extends ConsumerWidget {
  final MapState state;
  final MapNotifier notifier;

  const _FilterIconWithBadge({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Map filters',
          onPressed: notifier.toggleFiltersPanel,
        ),
        if (!state.filters.isDefault)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              key: const Key('filter_active_badge'),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFB42318),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filters panel (collapsible)
// ---------------------------------------------------------------------------

class _FiltersPanel extends StatelessWidget {
  final MapState state;
  final MapNotifier notifier;

  const _FiltersPanel({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Time range',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: notifier.resetFilters,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _timeChip(context, 'Last hour', MapTimeRange.hour),
                const SizedBox(width: 8),
                _timeChip(context, '6 hours', MapTimeRange.sixHours),
                const SizedBox(width: 8),
                _timeChip(context, '24 hours', MapTimeRange.day),
                const SizedBox(width: 8),
                _timeChip(context, 'All time', MapTimeRange.all),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show city labels'),
            value: state.showCityLabels,
            onChanged: (_) => notifier.toggleCityLabels(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _timeChip(BuildContext context, String label, MapTimeRange range) {
    final selected = state.filters.timeRange == range;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => notifier.updateFilters(
        state.filters.copyWith(timeRange: range),
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
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: _categoryChips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(chip.label),
                    selected: state.filters.category == chip.category,
                    selectedColor:
                        (_categoryColors[chip.category] ?? Colors.grey)
                            .withValues(alpha: 0.2),
                    onSelected: (_) => notifier.updateFilters(
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

// ---------------------------------------------------------------------------
// Map canvas
// ---------------------------------------------------------------------------

class _MapCanvas extends StatelessWidget {
  final MapState state;
  final MapController mapController;
  final void Function(MapReport) onPinTap;

  const _MapCanvas({
    required this.state,
    required this.mapController,
    required this.onPinTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.frontline.app',
        ),
        MarkerLayer(
          markers: state.reports
              .map((r) => _buildMarker(r))
              .toList(),
        ),
      ],
    );
  }

  Marker _buildMarker(MapReport report) {
    final isRecent = DateTime.now().difference(report.createdAt).inHours < 1;
    final color =
        _categoryColors[_categoryFromString(report.category)] ??
        const Color(0xFF374151);

    return Marker(
      point: LatLng(report.lat, report.lng),
      width: isRecent ? 36 : 28,
      height: isRecent ? 36 : 28,
      child: GestureDetector(
        onTap: () => onPinTap(report),
        child: _PinMarker(color: color, isRecent: isRecent),
      ),
    );
  }

  MapCategory _categoryFromString(String s) {
    return MapCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => MapCategory.all,
    );
  }
}

const _defaultCenter = LatLng(50.45, 30.52);
const _defaultZoom = 6.0;

class _PinMarker extends StatelessWidget {
  final Color color;
  final bool isRecent;

  const _PinMarker({required this.color, required this.isRecent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isRecent)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.25),
            ),
          ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pin details card
// ---------------------------------------------------------------------------

class _PinDetailsCard extends StatelessWidget {
  final MapReport report;
  final VoidCallback onClose;
  final VoidCallback onSeeAll;
  final VoidCallback onSetAlert;

  const _PinDetailsCard({
    required this.report,
    required this.onClose,
    required this.onSeeAll,
    required this.onSetAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.locationLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Deselect',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.list, size: 16),
                label: const Text('See all'),
                onPressed: onSeeAll,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.notifications_outlined, size: 16),
                label: const Text('Set alert'),
                onPressed: onSetAlert,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity section
// ---------------------------------------------------------------------------

class _RecentActivitySection extends StatelessWidget {
  final List<MapReport> reports;
  final void Function(MapReport) onTap;

  const _RecentActivitySection({required this.reports, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final recent = reports.take(5).toList();
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Recent activity',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No events in this area'),
            )
          else
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: recent.length,
                itemBuilder: (_, i) {
                  final r = recent[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: _categoryColors[
                            _categoryFromString(r.category)] ??
                          Colors.grey,
                    ),
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(r.locationLabel),
                    onTap: () => onTap(r),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  MapCategory _categoryFromString(String s) {
    return MapCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => MapCategory.all,
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
        color: const Color(0xFFB42318),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Events in $locationLabel',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: reports.isEmpty
                ? const Center(child: Text('No events found'))
                : ListView.builder(
                    controller: controller,
                    itemCount: reports.length,
                    itemBuilder: (_, i) {
                      final r = reports[i];
                      return ListTile(
                        title: Text(r.title),
                        subtitle: Text(r.locationLabel),
                        trailing: _StatusChip(status: r.status),
                        onTap: () => Navigator.of(context).pop(),
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
  final Set<MapCategory> _selectedCategories = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Set alert for ${widget.locationLabel}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Radius: ${_radiusKm.round()} km'),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 20,
            divisions: 19,
            label: '${_radiusKm.round()} km',
            onChanged: (v) => setState(() => _radiusKm = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Event types',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _categoryChips
                .where((c) => c.category != MapCategory.all)
                .map(
                  (c) => FilterChip(
                    label: Text(c.label),
                    selected: _selectedCategories.contains(c.category),
                    onSelected: (v) => setState(
                      () => v
                          ? _selectedCategories.add(c.category)
                          : _selectedCategories.remove(c.category),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alert saved')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Turn on alerts'),
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
      'disputed' => ('Disputed', const Color(0xFFB42318)),
      _ => ('Pending', const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
