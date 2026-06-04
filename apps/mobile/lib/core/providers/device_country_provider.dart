import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

final deviceCountryProvider = FutureProvider<String>((ref) async {
  return _resolveCountry();
});

Future<String> _resolveCountry() async {
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

  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
  );

  final placemarks = await placemarkFromCoordinates(
    pos.latitude,
    pos.longitude,
  );
  if (placemarks.isEmpty) return 'Local Reports';

  return placemarks.first.country ?? 'Local Reports';
}
