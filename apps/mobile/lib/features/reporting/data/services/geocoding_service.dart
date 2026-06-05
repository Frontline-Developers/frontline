import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart' as geo;

abstract interface class GeocodingService {
  /// Reverse-geocodes [lat]/[lng] to a structured label.
  /// Format: "Locality, SubLocality, Country" — empty parts omitted.
  /// Returns null on failure or on web (geocoding package not supported on web).
  Future<String?> reverseGeocode(double lat, double lng);

  /// Forward-geocodes [address] to the first matching coordinates.
  /// Returns null when no match is found or on any error.
  Future<({double lat, double lng})?> forwardGeocode(String address);
}

class GeocodingServiceImpl implements GeocodingService {
  const GeocodingServiceImpl();

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    if (kIsWeb) return null;
    try {
      final marks = await geo.placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      final parts = [
        p.locality,
        p.subLocality?.isNotEmpty == true
            ? p.subLocality
            : p.subAdministrativeArea,
        p.country,
      ].whereType<String>().where((s) => s.isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<({double lat, double lng})?> forwardGeocode(String address) async {
    if (kIsWeb) return null;
    try {
      final locs = await geo.locationFromAddress(address);
      if (locs.isEmpty) return null;
      return (lat: locs.first.latitude, lng: locs.first.longitude);
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
