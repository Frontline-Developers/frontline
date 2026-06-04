import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

final deviceCountryProvider = FutureProvider<String>(
  (ref) => _resolveCountry(),
);

Future<String> _resolveCountry() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'Local Reports';

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Local Reports';
    }

    // Prefer cached position — instant. Only do a live fix if no cache exists,
    // and cap it at 8 seconds so the header never hangs.
    Position? pos = await Geolocator.getLastKnownPosition();
    pos ??= await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 8));

    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    return placemarks.firstOrNull?.country ?? 'Local Reports';
  } catch (_) {
    return 'Local Reports';
  }
}
