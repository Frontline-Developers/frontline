import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reporting_provider.dart';
import 'report_theme.dart';

class StepLocation extends ConsumerStatefulWidget {
  const StepLocation({super.key});

  @override
  ConsumerState<StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends ConsumerState<StepLocation>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(reportingNotifierProvider).draft;
    _controller = TextEditingController(text: draft.locationLabel);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybePrefillCoords();
      _anim.forward();
    });
  }

  void _maybePrefillCoords() {
    final draft = ref.read(reportingNotifierProvider).draft;
    if (draft.lat == null || draft.lng == null) {
      // TODO(WBS 3.11): wire `geolocator` permission flow + getCurrentPosition.
      // Until then we inject a deterministic placeholder (Kharkiv) so the
      // submit pipeline can be exercised end-to-end. The user-input label
      // (city/district text) is what they actually see; the underlying coords
      // are server-fuzzed ±3km regardless.
      ref
          .read(reportingNotifierProvider.notifier)
          .updateDraft(lat: 50.0241, lng: 36.2289);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APPROXIMATE LOCATION',
          style: ReportTextStyles.sectionLabel,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: (v) => ref
              .read(reportingNotifierProvider.notifier)
              .updateDraft(locationLabel: v),
          decoration: InputDecoration(
            hintText: 'City, district, neighborhood...',
            hintStyle: const TextStyle(
              color: ReportPalette.inkTertiary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: ReportPalette.inkTertiary,
              size: 20,
            ),
            filled: true,
            fillColor: ReportPalette.raised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ReportPalette.navy,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          style: const TextStyle(color: ReportPalette.ink, fontSize: 15),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ReportPalette.card,
            border: Border.all(color: ReportPalette.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.gps_off,
                    color: ReportPalette.navy,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Location is randomized',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ReportPalette.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      if (_anim.value < 0.9) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ReportPalette.verifiedSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              color: ReportPalette.verified,
                              size: 11,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '±3 KM',
                              style: TextStyle(
                                color: ReportPalette.verified,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => SizedBox(
                  height: 130,
                  child: CustomPaint(
                    painter: _FuzzPainter(progress: _anim.value),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ReportPalette.inkSecondary,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: 'Your exact coordinates are '),
                    TextSpan(
                      text: 'never sent',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ReportPalette.ink,
                      ),
                    ),
                    TextSpan(
                      text:
                          '. We perturb by up to ±3km so the report can\'t be traced to your home, but the affected area is still meaningful.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FuzzPainter extends CustomPainter {
  final double progress;
  _FuzzPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = ReportPalette.raised;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, bg);

    // grid
    final grid = Paint()
      ..color = const Color(0x0F000000)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final center = Offset(size.width / 2, size.height / 2);

    // Actual point (fades as fuzz reveals)
    final actualPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 1.0 - 0.7 * progress);
    canvas.drawCircle(center, 4, actualPaint);

    // Randomization radius
    final radius = 45.0 * progress;
    final radiusFill = Paint()
      ..color = ReportPalette.navy.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, radiusFill);
    final radiusStroke = Paint()
      ..color = ReportPalette.navy
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedCircle(canvas, center, radius, radiusStroke);

    // Stored (fuzzed) point — offset deterministically
    if (progress > 0.4) {
      final t = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      final stored = center + const Offset(22, -18);
      final stroke = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final fill = Paint()..color = ReportPalette.navy;
      canvas.drawCircle(stored, 7 * t, fill);
      canvas.drawCircle(stored, 7 * t, stroke);
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset c, double r, Paint p) {
    const segments = 36;
    final step = (2 * pi) / segments;
    for (var i = 0; i < segments; i++) {
      if (i.isEven) continue;
      final a1 = step * i;
      final a2 = step * (i + 1);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a1,
        a2 - a1,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FuzzPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
