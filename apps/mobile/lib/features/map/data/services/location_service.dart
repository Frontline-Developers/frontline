import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

abstract interface class LocationService {
  /// Returns the device's current GPS position, or null if unavailable /
  /// permission denied. Raw coordinates stay on-device — never uploaded.
  Future<LatLng?> getCurrentLocation();
}

class LocationServiceImpl implements LocationService {
  const LocationServiceImpl();

  @override
  Future<LatLng?> getCurrentLocation() async {
    try {
      // Check / request permission.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
