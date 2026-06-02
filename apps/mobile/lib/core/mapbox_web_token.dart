import 'dart:js_interop';

@JS('mapboxgl')
external _Mapboxgl? get _mapboxgl;

@JS()
@staticInterop
class _Mapboxgl {}

extension _MapboxglX on _Mapboxgl {
  external set accessToken(String value);
}

/// Sets `mapboxgl.accessToken` on the Mapbox GL JS library loaded in
/// web/index.html. This bypasses mapbox_maps_flutter's `MapboxOptions.setAccessToken`,
/// which crashes under Flutter web DDC due to a non-const `bool.fromEnvironment`
/// in its `log_configuration.dart`.
void setMapboxWebToken(String token) {
  final mapboxgl = _mapboxgl;
  if (mapboxgl == null) return;
  mapboxgl.accessToken = token;
}
