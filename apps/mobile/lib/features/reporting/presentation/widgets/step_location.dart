import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';

import '../providers/reporting_provider.dart';
import 'report_theme.dart';

class StepLocation extends ConsumerStatefulWidget {
  const StepLocation({super.key});

  @override
  ConsumerState<StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends ConsumerState<StepLocation> {
  late final TextEditingController _labelController;
  late final MapController _mapController;
  bool _locating = false;

  // Default global view when the user hasn't picked yet.
  static const LatLng _defaultCenter = LatLng(20.0, 0.0);
  static const double _defaultZoom = 1.5;
  static const double _pickedZoom = 12.0;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(reportingNotifierProvider).draft;
    _labelController = TextEditingController(text: draft.locationLabel);
    _mapController = MapController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Fires whenever the map's camera changes — including programmatic moves
  /// (e.g. `controller.move` from `_useMyLocation`). We deliberately do NOT
  /// gate on `hasGesture` so "use my location" also commits the new center.
  /// Fuzzing happens server-side; spamming `updateDraft` is cheap.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!mounted) return;
    ref
        .read(reportingNotifierProvider.notifier)
        .updateDraft(lat: camera.center.latitude, lng: camera.center.longitude);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) {
        _showSnack('Location permission denied. Pan the map to pick a spot.');
        return;
      }
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.low,
        ),
      );
      if (!mounted) return;
      _mapController.move(LatLng(pos.latitude, pos.longitude), _pickedZoom);
    } catch (e) {
      _showSnack('Could not get your location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return permission == geo.LocationPermission.always ||
        permission == geo.LocationPermission.whileInUse;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportingNotifierProvider).draft;
    final hasPickedCoords = draft.lat != null && draft.lng != null;
    final initialCenter = hasPickedCoords
        ? LatLng(draft.lat!, draft.lng!)
        : _defaultCenter;
    final initialZoom = hasPickedCoords ? _pickedZoom : _defaultZoom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APPROXIMATE LOCATION',
          style: ReportTextStyles.sectionLabel,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          onChanged: (v) => ref
              .read(reportingNotifierProvider.notifier)
              .updateDraft(locationLabel: v),
          decoration: InputDecoration(
            hintText: 'City, district, neighborhood...',
            hintStyle: const TextStyle(
              color: ReportPalette.inkTertiary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: ReportPalette.inkTertiary,
              size: 20,
            ),
            filled: true,
            fillColor: ReportPalette.raised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ReportPalette.navy,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          style: const TextStyle(color: ReportPalette.ink, fontSize: 15),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: ReportPalette.card,
            border: Border.all(color: ReportPalette.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.gps_off,
                      color: ReportPalette.navy,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Pan the map to pick a spot',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ReportPalette.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ReportPalette.navySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.adjust,
                            color: ReportPalette.navy,
                            size: 11,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '±3 KM',
                            style: TextStyle(
                              color: ReportPalette.navy,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FlutterMap(
                      key: const ValueKey('locationPickerMap'),
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: initialZoom,
                        onPositionChanged: _onPositionChanged,
                        // Disable rotation; users only pan/zoom.
                        interactionOptions: const InteractionOptions(
                          flags:
                              InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom |
                              InteractiveFlag.scrollWheelZoom,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'app.frontline.mobile',
                          maxNativeZoom: 19,
                        ),
                      ],
                    ),
                    const IgnorePointer(
                      key: Key('locationCrosshair'),
                      child: _CrosshairOverlay(),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _RecenterButton(
                        loading: _locating,
                        onPressed: _useMyLocation,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 11.5,
                      color: ReportPalette.inkSecondary,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'The pin shows your pick. We '),
                      TextSpan(
                        text: 'fuzz the coordinates ±3km on the server',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ReportPalette.ink,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' before storage, so the report can\'t be traced to your home but the affected area is still meaningful.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CrosshairOverlay extends StatelessWidget {
  const _CrosshairOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ±3km radius ring (decorative; actual fuzz is server-side).
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ReportPalette.navy.withValues(alpha: 0.10),
                border: Border.all(
                  color: ReportPalette.navy.withValues(alpha: 0.65),
                  width: 1.5,
                ),
              ),
            ),
            // Center pin.
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ReportPalette.navy,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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

class _RecenterButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _RecenterButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ReportPalette.navy,
                    ),
                  )
                : const Icon(
                    Icons.my_location,
                    color: ReportPalette.navy,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}
