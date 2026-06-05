import 'dart:async';

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
  bool _geocoding = false;
  bool _confirmed = false;
  Timer? _reverseGeocodeTimer;
  LatLng _displayCenter = _defaultCenter;

  // Default global view when the user hasn't picked yet.
  static const LatLng _defaultCenter = LatLng(20.0, 0.0);
  static const double _defaultZoom = 1.5;
  static const double _pickedZoom = 12.0;
  static const double _fuzzRadiusMeters = 3000;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(reportingNotifierProvider).draft;
    _labelController = TextEditingController(text: draft.locationLabel);
    _mapController = MapController();
  }

  @override
  void dispose() {
    _reverseGeocodeTimer?.cancel();
    _labelController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!mounted) return;
    setState(() => _displayCenter = camera.center);
    if (!hasGesture) return;
    ref
        .read(reportingNotifierProvider.notifier)
        .updateDraft(lat: camera.center.latitude, lng: camera.center.longitude);

    // Show spinner immediately and clear confirmed state on new pan.
    setState(() {
      if (!_geocoding) _geocoding = true;
      _confirmed = false;
    });

    // Debounce reverse geocoding — cancel any pending call and reschedule.
    _reverseGeocodeTimer?.cancel();
    _reverseGeocodeTimer = Timer(const Duration(milliseconds: 800), () {
      _reverseGeocode(camera.center.latitude, camera.center.longitude);
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final label = await ref
          .read(geocodingServiceProvider)
          .reverseGeocode(lat, lng);
      if (!mounted) return;
      if (label != null) {
        _labelController.text = label;
        ref
            .read(reportingNotifierProvider.notifier)
            .updateDraft(locationLabel: label);
        if (mounted) setState(() => _confirmed = true);
      } else {
        _labelController.clear();
        ref
            .read(reportingNotifierProvider.notifier)
            .updateDraft(locationLabel: '');
        if (mounted) setState(() => _confirmed = false);
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _forwardGeocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final svc = ref.read(geocodingServiceProvider);
      final result = await svc.forwardGeocode(trimmed);
      if (!mounted) return;
      if (result != null) {
        _mapController.move(LatLng(result.lat, result.lng), _pickedZoom);
        ref
            .read(reportingNotifierProvider.notifier)
            .updateDraft(lat: result.lat, lng: result.lng);
        // Reverse-geocode the resolved position to get a structured label.
        final label = await svc.reverseGeocode(result.lat, result.lng);
        if (!mounted) return;
        if (label != null) {
          _labelController.text = label;
          ref
              .read(reportingNotifierProvider.notifier)
              .updateDraft(locationLabel: label);
        }
      } else {
        _showSnack('Address not found. Try a different search.');
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
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
      ref
          .read(reportingNotifierProvider.notifier)
          .updateDraft(lat: pos.latitude, lng: pos.longitude);
      await _reverseGeocode(pos.latitude, pos.longitude);
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
          textInputAction: TextInputAction.search,
          onChanged: (v) => ref
              .read(reportingNotifierProvider.notifier)
              .updateDraft(locationLabel: v),
          onSubmitted: _forwardGeocode,
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
            suffixIcon: _geocoding
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ReportPalette.navy,
                      ),
                    ),
                  )
                : IconButton(
                    key: const Key('locationSearchButton'),
                    icon: const Icon(
                      Icons.search,
                      color: ReportPalette.inkTertiary,
                      size: 20,
                    ),
                    tooltip: 'Search address',
                    onPressed: () => _forwardGeocode(_labelController.text),
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
                          tileProvider: NetworkTileProvider(),
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _displayCenter,
                              radius: _fuzzRadiusMeters,
                              useRadiusInMeter: true,
                              color: ReportPalette.navy.withValues(alpha: 0.10),
                              borderColor: ReportPalette.navy.withValues(
                                alpha: 0.65,
                              ),
                              borderStrokeWidth: 1.5,
                            ),
                          ],
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ReportPalette.inkSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'The pin shows your pick. We '),
                      const TextSpan(
                        text: 'fuzz the coordinates ±3km on the server',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ReportPalette.ink,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' before storage, so the report can\'t be traced to your home but the affected area is still meaningful.',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: _confirmed
                      ? _ConfirmedBadge(label: _labelController.text)
                      : OutlinedButton.icon(
                          onPressed: _geocoding
                              ? null
                              : () => _reverseGeocode(
                                  _displayCenter.latitude,
                                  _displayCenter.longitude,
                                ),
                          icon: _geocoding
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ReportPalette.navy,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  size: 16,
                                  color: ReportPalette.navy,
                                ),
                          label: Text(
                            _geocoding
                                ? 'Looking up location…'
                                : 'Confirm this location',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ReportPalette.navy,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(
                              color: ReportPalette.navy,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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

class _ConfirmedBadge extends StatelessWidget {
  final String label;
  const _ConfirmedBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E7D32), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label.isNotEmpty ? 'Saved as "$label"' : 'Location confirmed',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosshairOverlay extends StatelessWidget {
  const _CrosshairOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
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
