import '../../domain/entities/map_filters.dart';
import '../../domain/entities/map_report.dart';
import 'map_datasource.dart';

/// Dev/test mock datasource — returns seeded Ukraine city data.
/// Swap [_mapDatasourceProvider] to [MockMapDatasource()] for local dev.
class MockMapDatasource implements MapDatasource {
  // Based on the design mockups: Sumy 2 · Kyiv 3 · Kharkiv 7 ·
  // Bakhmut 8 · Zaporizhzhia 5 · Odessa 1 · Mariupol 2
  static final List<MapReport> _seed = [
    // ── Sumy — 2 combat ──────────────────────────────────────────────
    _r(
      'sumy-1',
      50.91,
      34.80,
      'combat',
      'Artillery shelling near Sumy outskirts',
      'Sumy',
      'pending',
      -30,
    ),
    _r(
      'sumy-2',
      50.90,
      34.82,
      'combat',
      'Drone activity reported over Sumy',
      'Sumy',
      'verified',
      -90,
    ),

    // ── Kyiv — 3 humanitarian aid ────────────────────────────────────
    _r(
      'kyiv-1',
      50.45,
      30.52,
      'aid',
      'EU aid convoy arrived at Kyiv distribution centre',
      'Kyiv',
      'verified',
      -45,
    ),
    _r(
      'kyiv-2',
      50.46,
      30.50,
      'aid',
      'Medical supplies unloaded at Kyiv central hospital',
      'Kyiv',
      'verified',
      -120,
    ),
    _r(
      'kyiv-3',
      50.44,
      30.54,
      'aid',
      'Volunteer shelter opened in Kyiv Podil district',
      'Kyiv',
      'pending',
      -200,
    ),

    // ── Kharkiv — 7 combat ───────────────────────────────────────────
    _r(
      'kharkiv-1',
      49.99,
      36.23,
      'combat',
      'Missile strike reported near Kharkiv metro',
      'Kharkiv',
      'verified',
      -15,
    ),
    _r(
      'kharkiv-2',
      50.00,
      36.25,
      'combat',
      'Air raid siren active across Kharkiv region',
      'Kharkiv',
      'verified',
      -35,
    ),
    _r(
      'kharkiv-3',
      49.98,
      36.20,
      'combat',
      'Shelling heard in northern Kharkiv',
      'Kharkiv',
      'pending',
      -55,
    ),
    _r(
      'kharkiv-4',
      50.01,
      36.22,
      'combat',
      'Emergency services responding east of Kharkiv',
      'Kharkiv',
      'disputed',
      -80,
    ),
    _r(
      'kharkiv-5',
      49.97,
      36.26,
      'combat',
      'Blackout reported in Kharkiv Saltivka district',
      'Kharkiv',
      'verified',
      -110,
    ),
    _r(
      'kharkiv-6',
      50.02,
      36.21,
      'combat',
      'Ground movement spotted near Kharkiv borders',
      'Kharkiv',
      'pending',
      -150,
    ),
    _r(
      'kharkiv-7',
      49.96,
      36.28,
      'combat',
      'Explosion reported near Kharkiv industrial zone',
      'Kharkiv',
      'pending',
      -180,
    ),

    // ── Bakhmut — 8 combat ───────────────────────────────────────────
    _r(
      'bakhmut-1',
      48.60,
      38.00,
      'combat',
      'Heavy shelling on Bakhmut northern road',
      'Bakhmut',
      'verified',
      -20,
    ),
    _r(
      'bakhmut-2',
      48.61,
      38.02,
      'combat',
      'Frontline movement reported near Bakhmut centre',
      'Bakhmut',
      'verified',
      -40,
    ),
    _r(
      'bakhmut-3',
      48.59,
      37.98,
      'combat',
      'Supply route to Bakhmut reportedly under fire',
      'Bakhmut',
      'pending',
      -65,
    ),
    _r(
      'bakhmut-4',
      48.62,
      38.01,
      'combat',
      'Drone strikes near Bakhmut sugar factory',
      'Bakhmut',
      'disputed',
      -95,
    ),
    _r(
      'bakhmut-5',
      48.58,
      38.03,
      'combat',
      'Night attack on Bakhmut defensive line',
      'Bakhmut',
      'pending',
      -130,
    ),
    _r(
      'bakhmut-6',
      48.63,
      37.99,
      'combat',
      'Artillery exchange near Bakhmut outskirts',
      'Bakhmut',
      'verified',
      -160,
    ),
    _r(
      'bakhmut-7',
      48.57,
      38.04,
      'combat',
      'Street fighting reported in eastern Bakhmut',
      'Bakhmut',
      'pending',
      -200,
    ),
    _r(
      'bakhmut-8',
      48.64,
      37.97,
      'combat',
      'Evacuation corridor temporarily closed at Bakhmut',
      'Bakhmut',
      'verified',
      -240,
    ),

    // ── Zaporizhzhia — 5 mixed ───────────────────────────────────────
    _r(
      'zaporizhzhia-1',
      47.83,
      35.16,
      'alert',
      'Air alert activated across Zaporizhzhia oblast',
      'Zaporizhzhia',
      'verified',
      -25,
    ),
    _r(
      'zaporizhzhia-2',
      47.84,
      35.18,
      'combat',
      'Shelling reported near Zaporizhzhia power station',
      'Zaporizhzhia',
      'verified',
      -50,
    ),
    _r(
      'zaporizhzhia-3',
      47.82,
      35.14,
      'alert',
      'Explosion heard south of Zaporizhzhia city',
      'Zaporizhzhia',
      'pending',
      -75,
    ),
    _r(
      'zaporizhzhia-4',
      47.85,
      35.15,
      'combat',
      'Military convoy movement near Zaporizhzhia',
      'Zaporizhzhia',
      'pending',
      -100,
    ),
    _r(
      'zaporizhzhia-5',
      47.81,
      35.17,
      'displaced',
      'Evacuation buses departing from Zaporizhzhia',
      'Zaporizhzhia',
      'verified',
      -140,
    ),

    // ── Odessa — 1 infra ─────────────────────────────────────────────
    _r(
      'odessa-1',
      46.48,
      30.72,
      'infra',
      'Grain corridor operations reported in Odessa port',
      'Odessa',
      'verified',
      -300,
    ),

    // ── Mariupol — 2 displaced ───────────────────────────────────────
    _r(
      'mariupol-1',
      47.10,
      37.54,
      'displaced',
      'Humanitarian corridor update for Mariupol residents',
      'Mariupol',
      'pending',
      -400,
    ),
    _r(
      'mariupol-2',
      47.11,
      37.56,
      'displaced',
      'Red Cross access requested for Mariupol area',
      'Mariupol',
      'disputed',
      -500,
    ),
  ];

  @override
  Stream<List<MapReport>> watchReportsNear(
    double lat,
    double lng,
    double radiusKm, {
    MapFilters filters = const MapFilters(),
  }) {
    final now = DateTime.now();
    final filtered = _seed.where((r) {
      // Category filter
      if (filters.category != MapCategory.all) {
        if (r.category != filters.category.name) return false;
      }
      // Time range filter
      if (filters.timeRange != MapTimeRange.all) {
        final cutoff = now.subtract(_durationFor(filters.timeRange));
        if (r.createdAt.isBefore(cutoff)) return false;
      }
      return true;
    }).toList();

    return Stream.value(filtered);
  }

  static Duration _durationFor(MapTimeRange range) => switch (range) {
    MapTimeRange.hour => const Duration(hours: 1),
    MapTimeRange.sixHours => const Duration(hours: 6),
    MapTimeRange.day => const Duration(hours: 24),
    MapTimeRange.all => Duration.zero,
  };

  static MapReport _r(
    String id,
    double lat,
    double lng,
    String category,
    String title,
    String locationLabel,
    String status,
    int minutesAgo,
  ) => MapReport(
    id: id,
    lat: lat,
    lng: lng,
    category: category,
    title: title,
    locationLabel: locationLabel,
    status: status,
    createdAt: DateTime.now().add(Duration(minutes: minutesAgo)),
  );
}
