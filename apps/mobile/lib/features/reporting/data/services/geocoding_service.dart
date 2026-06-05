import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'dart:convert';

abstract interface class GeocodingService {
  /// Reverse-geocodes [lat]/[lng] to a structured label.
  /// Format: "Locality, City, Country" — empty/duplicate parts omitted.
  /// Falls back to Nominatim on web where the geocoding package is unavailable.
  Future<String?> reverseGeocode(double lat, double lng);

  /// Forward-geocodes [address] to the first matching coordinates.
  /// Returns null when no match is found or on any error.
  Future<({double lat, double lng})?> forwardGeocode(String address);
}

class GeocodingServiceImpl implements GeocodingService {
  const GeocodingServiceImpl();

  @override
  Future<String?> reverseGeocode(double lat, double lng) async {
    if (kIsWeb) return _nominatimReverse(lat, lng);
    try {
      final marks = await geo.placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      // Use administrativeArea (city-level) so that searching "Bangkok" finds
      // reports made anywhere in Bangkok, not just a specific sub-district.
      final rawParts = [
        p.locality,
        p.administrativeArea,
        p.country,
      ].whereType<String>().where((s) => s.isNotEmpty).toList();
      // Deduplicate consecutive identical parts (e.g. "Bangkok, Bangkok, Thailand").
      final parts = <String>[];
      for (final part in rawParts) {
        if (parts.isEmpty || parts.last.toLowerCase() != part.toLowerCase()) {
          parts.add(part);
        }
      }
      return parts.isEmpty ? null : parts.join(', ');
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<({double lat, double lng})?> forwardGeocode(String address) async {
    if (kIsWeb) return _nominatimForward(address);
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

  // Nominatim fallback used on web (geocoding package requires native platform APIs).
  Future<String?> _nominatimReverse(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final res = await http
          .get(uri, headers: {'Accept-Language': 'en'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return null;
      final locality =
          (address['city'] as String?) ??
          (address['town'] as String?) ??
          (address['village'] as String?) ??
          (address['suburb'] as String?);
      final region = address['state'] as String?;
      final country = address['country'] as String?;
      final rawParts = [
        locality,
        region,
        country,
      ].whereType<String>().where((s) => s.isNotEmpty).toList();
      final parts = <String>[];
      for (final part in rawParts) {
        if (parts.isEmpty || parts.last.toLowerCase() != part.toLowerCase()) {
          parts.add(part);
        }
      }
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<({double lat, double lng})?> _nominatimForward(String address) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(address)}&format=json&limit=1',
      );
      final res = await http
          .get(uri, headers: {'Accept-Language': 'en'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lng = double.tryParse(first['lon'] as String? ?? '');
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }
}
