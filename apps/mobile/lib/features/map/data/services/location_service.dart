import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

abstract interface class LocationService {
  /// Returns the device's current GPS position, or null if unavailable /
  /// permission denied. Raw coordinates stay on-device — never uploaded.
  Future<LatLng?> getCurrentLocation();

  /// Reverse-geocodes [lat]/[lng] to a human-readable city name.
  /// Returns null if geocoding fails or the result is empty.
  Future<String?> getCityName(double lat, double lng);

  /// Forward-geocodes [address] to the first matching LatLng.
  /// Returns null if no match found or on any error.
  Future<LatLng?> searchLocation(String address);
}

class LocationServiceImpl implements LocationService {
  const LocationServiceImpl();

  @override
  Future<LatLng?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Last-known position is instant (no hardware GPS required).
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);

      // Fresh fix with low accuracy (network/wifi) — typically <3 seconds.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getCityName(double lat, double lng) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      // Prefer locality (city), fall back to sub-administrative area, then country.
      return p.locality?.isNotEmpty == true
          ? p.locality
          : p.subAdministrativeArea?.isNotEmpty == true
          ? p.subAdministrativeArea
          : p.country;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LatLng?> searchLocation(String address) async {
    try {
      final locations = await geo.locationFromAddress(address);
      if (locations.isEmpty) return null;
      return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (_) {
      return null;
    }
  }
}
