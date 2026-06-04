part of 'map_screen.dart';

// ---------------------------------------------------------------------------
// Pin details card (selected state)
// ---------------------------------------------------------------------------

class _PinDetailsCard extends StatelessWidget {
  final MapReport report;
  final List<MapReport> clusterReports;
  final VoidCallback onClose;
  final VoidCallback onSeeAll;
  final VoidCallback onSetAlert;

  const _PinDetailsCard({
    required this.report,
    required this.clusterReports,
    required this.onClose,
    required this.onSeeAll,
    required this.onSetAlert,
  });

  @override
  Widget build(BuildContext context) {
    final category = MapCategory.values.firstWhere(
      (c) => c.name == report.category,
      orElse: () => MapCategory.all,
    );
    final color = _categoryColors[category] ?? Colors.grey;
    final icon = _categoryIcons[category] ?? Icons.circle;
    final count = clusterReports.length;
    final label = _chipLabel(category);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.locationLabel,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$label · $count events in last 24h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Report preview card ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _combatRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CITIZEN REPORT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(report.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${report.locationLabel} · Unverified citizen submission',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Action buttons ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: const Text(
                      'See all',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: onSeeAll,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(
                      Icons.notifications_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Set alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: onSetAlert,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _chipLabel(MapCategory cat) => _categoryChips
      .firstWhere(
        (c) => c.category == cat,
        orElse: () => (label: 'Other', category: MapCategory.all),
      )
      .label;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Recent activity section (no pin selected)
// ---------------------------------------------------------------------------

class _RecentActivitySection extends StatelessWidget {
  final List<_LocationCluster> clusters;
  final void Function(_LocationCluster) onTap;

  const _RecentActivitySection({required this.clusters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final recent = clusters.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No events in this area',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          )
        else
          ...List.generate(
            recent.length,
            (i) => Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                i < recent.length - 1 ? 8 : 16,
              ),
              child: _RecentActivityCard(
                cluster: recent[i],
                onTap: () => onTap(recent[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final _LocationCluster cluster;
  final VoidCallback onTap;

  const _RecentActivityCard({required this.cluster, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[cluster.dominantCategory] ?? Colors.grey;
    final icon = _categoryIcons[cluster.dominantCategory] ?? Icons.circle;
    final chipLabel = _categoryChips
        .firstWhere(
          (c) => c.category == cluster.dominantCategory,
          orElse: () => (label: 'Other', category: MapCategory.all),
        )
        .label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cluster.locationLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chipLabel,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cluster.count} events',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        color: _combatRed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          error,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// See all sheet
// ---------------------------------------------------------------------------

class _SeeAllSheet extends StatelessWidget {
  final String locationLabel;
  final List<MapReport> reports;
  final MapCategory category;

  const _SeeAllSheet({
    required this.locationLabel,
    required this.reports,
    required this.category,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[category] ?? Colors.grey;
    final icon = _categoryIcons[category] ?? Icons.circle;
    final categoryLabel = _categoryChips
        .firstWhere(
          (c) => c.category == category,
          orElse: () => (label: 'Other', category: MapCategory.all),
        )
        .label;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reports.length} events · $categoryLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Expanded(
            child: reports.isEmpty
                ? const Center(child: Text('No events found'))
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: reports.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = reports[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/report/${r.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surfaceGrey,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  color: color.withValues(alpha: 0.15),
                                  child: Icon(
                                    icon,
                                    color: color.withValues(alpha: 0.5),
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'CITIZEN REPORT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '· ${_timeAgo(r.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      r.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                        height: 1.35,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set alert sheet
// ---------------------------------------------------------------------------

class _SetAlertSheet extends ConsumerStatefulWidget {
  final String locationLabel;
  final double lat;
  final double lng;

  const _SetAlertSheet({
    required this.locationLabel,
    required this.lat,
    required this.lng,
  });

  @override
  ConsumerState<_SetAlertSheet> createState() => _SetAlertSheetState();
}

class _SetAlertSheetState extends ConsumerState<_SetAlertSheet> {
  double _radiusKm = 5;
  bool _confirmed = false;
  final Map<MapCategory, bool> _toggles = {
    MapCategory.combat: true,
    MapCategory.aid: false,
    MapCategory.alert: true,
    MapCategory.displaced: false,
    MapCategory.infra: false,
    MapCategory.other: false,
  };

  static const _alertCategories = [
    (label: 'Combat / strike', category: MapCategory.combat),
    (label: 'Humanitarian aid', category: MapCategory.aid),
    (label: 'Air alert / siren', category: MapCategory.alert),
    (label: 'Displaced persons', category: MapCategory.displaced),
    (label: 'Infrastructure', category: MapCategory.infra),
    (label: 'Other', category: MapCategory.other),
  ];

  Widget _buildConfirmation(BuildContext context) {
    final enabledCount = _toggles.values.where((v) => v).length;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alert set',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You can change this anytime',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _aidGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(
                Icons.notifications_active,
                color: _aidGreen,
                size: 40,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: "You'll be alerted about "),
                TextSpan(
                  text:
                      '$enabledCount event type${enabledCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const TextSpan(text: ' within '),
                TextSpan(
                  text: '${_radiusKm.round()}km',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                TextSpan(text: ' of ${widget.locationLabel}.'),
              ],
            ),
          ),
        ),
        SizedBox(height: 32 + bottom),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) return _buildConfirmation(context);
    final alertState = ref.watch(alertNotifierProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: _navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert for ${widget.locationLabel}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get notified when something happens nearby',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'NOTIFY ME ABOUT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
        ),
        for (int i = 0; i < _alertCategories.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            _categoryColors[_alertCategories[i].category] ??
                            Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _categoryIcons[_alertCategories[i].category] ??
                            Icons.circle,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _alertCategories[i].label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _toggles[_alertCategories[i].category] ?? false,
                      activeTrackColor: _navy,
                      activeThumbColor: Colors.white,
                      onChanged: (v) => setState(
                        () => _toggles[_alertCategories[i].category] = v,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < _alertCategories.length - 1) const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            'RADIUS — ${_radiusKm.round()} KM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _navy,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: Colors.white,
            overlayColor: _navy.withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 2,
            ),
            trackHeight: 3,
          ),
          child: Slider(
            value: _radiusKm,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (v) => setState(() => _radiusKm = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 km',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                '20 km',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Turn on alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: alertState.status == AlertStatus.saving
                  ? null
                  : () async {
                      final enabledCategories = _toggles.entries
                          .where((e) => e.value)
                          .map((e) => e.key.name)
                          .toList();
                      final uid =
                          ref.read(authNotifierProvider).user?.uid ??
                          'anonymous';
                      await ref
                          .read(alertNotifierProvider.notifier)
                          .save(
                            userId: uid,
                            locationLabel: widget.locationLabel,
                            lat: widget.lat,
                            lng: widget.lng,
                            radiusKm: _radiusKm,
                            categories: enabledCategories,
                          );
                      if (mounted) setState(() => _confirmed = true);
                    },
            ),
          ),
        ),
      ],
    );
  }
}
