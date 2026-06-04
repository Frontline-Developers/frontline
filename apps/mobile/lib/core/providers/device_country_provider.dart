import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

    // getLastKnownPosition is mobile-only — instant when cached.
    Position? pos;
    if (!kIsWeb) pos = await Geolocator.getLastKnownPosition();

    pos ??= await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 10));

    return await _countryFromCoords(pos.latitude, pos.longitude);
  } catch (_) {
    return 'Local Reports';
  }
}

Future<String> _countryFromCoords(double lat, double lng) async {
  // Native geocoding works on Android/iOS; on web it is not supported.
  if (!kIsWeb) {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      final name = marks.firstOrNull?.country;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
  }

  // Web fallback: Nominatim reverse-geocode (same OSM stack as the map tiles).
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lng&format=json',
    );
    final res = await http
        .get(uri, headers: {'Accept-Language': 'en', 'User-Agent': 'Frontline'})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      final name = address?['country'] as String?;
      if (name != null && name.isNotEmpty) return name;
    }
  } catch (_) {}

  return 'Local Reports';
}
