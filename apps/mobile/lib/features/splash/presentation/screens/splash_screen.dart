import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF1A3270);
const _kBgTop = Color(0xFF1E3A8A);
const _kRing = Color(0xFF4A6BB5);
const _kIcon = Colors.white;
const _kDuration = Duration(milliseconds: 2800);

// ── Screen ────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _radarCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _contentCtrl;

  late final Animation<double> _fadeIn;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    // Radar loop — each full cycle = one ring expanding + fading
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Progress bar fills over the splash duration
    _progressCtrl = AnimationController(vsync: this, duration: _kDuration)
      ..forward();

    _progress = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);

    // Content fades in quickly
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeIn = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);

    // Navigate when progress is done
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/feed');
      }
    });
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _progressCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient fills every pixel including status bar area
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kBgTop, _kBg],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // ── Radar icon ───────────────────────────────────────────────
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: AnimatedBuilder(
                      animation: _radarCtrl,
                      builder: (ctx, _) => CustomPaint(
                        painter: _RadarPainter(_radarCtrl.value),
                        child: Center(child: _AppIcon()),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Title ────────────────────────────────────────────────────
                  Text(
                    'Frontline',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: _kIcon,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Reports from the people on the frontline',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xAAFFFFFF),
                        height: 1.4,
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // ── Progress bar ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _progress,
                          builder: (ctx, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              minHeight: 3,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Loading live reports...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xCCFFFFFF),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Privacy note ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'No account · No tracking · IP never stored',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App icon ──────────────────────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.check, color: _kBgTop, size: 36),
    );
  }
}

// ── Radar painter ─────────────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double t; // 0.0 → 1.0 per cycle
  _RadarPainter(this.t);

  static const _ringCount = 3;
  static const _stagger = 1.0 / _ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (var i = 0; i < _ringCount; i++) {
      // Each ring starts at a different phase
      final phase = (t - i * _stagger) % 1.0;
      if (phase < 0) continue;

      final radius = _ease(phase) * maxRadius;
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.35;

      final paint = Paint()
        ..color = _kRing.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  double _ease(double x) => 1 - pow(1 - x, 3).toDouble();

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}
