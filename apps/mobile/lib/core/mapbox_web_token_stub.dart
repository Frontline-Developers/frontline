/// Non-web stub. On native platforms we use `MapboxOptions.setAccessToken`
/// directly from mapbox_maps_flutter; this function is intentionally a no-op
/// so the conditional import in main.dart compiles for VM targets.
void setMapboxWebToken(String token) {
  // Intentionally empty.
}
