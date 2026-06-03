import 'package:flutter/material.dart';

import 'report_theme.dart';

class ProcessingScreen extends StatelessWidget {
  final int step; // 0..4 — number of completed checklist items
  const ProcessingScreen({super.key, required this.step});

  static const _steps = [
    (icon: Icons.image_outlined, label: 'Stripping EXIF metadata'),
    (icon: Icons.gps_off, label: 'Randomizing GPS coordinates ±3km'),
    (icon: Icons.cloud_upload_outlined, label: 'Uploading media securely'),
    (icon: Icons.vpn_key_outlined, label: 'Generating anonymous token'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ReportPalette.navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.verified_user,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Securing your report',
            textAlign: TextAlign.center,
            style: ReportTextStyles.h1,
          ),
          const SizedBox(height: 6),
          const Text(
            'These steps run on your device before anything is sent.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ReportPalette.inkTertiary),
          ),
          const SizedBox(height: 28),
          ...List.generate(_steps.length, (i) {
            final s = _steps[i];
            final isDone = i < step;
            final isActive = i == step;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _ChecklistRow(
                icon: s.icon,
                label: s.label,
                state: isDone
                    ? _RowState.done
                    : isActive
                    ? _RowState.active
                    : _RowState.idle,
              ),
            );
          }),
        ],
      ),
    );
  }
}

enum _RowState { idle, active, done }

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final _RowState state;
  const _ChecklistRow({
    required this.icon,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (state) {
      case _RowState.done:
        bg = ReportPalette.verifiedSoft;
        fg = ReportPalette.verified;
        break;
      case _RowState.active:
        bg = ReportPalette.navySoft;
        fg = ReportPalette.navy;
        break;
      case _RowState.idle:
        bg = ReportPalette.raised;
        fg = ReportPalette.inkTertiary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: state == _RowState.active
                ? CircularProgressIndicator(strokeWidth: 2, color: fg)
                : Icon(
                    state == _RowState.done ? Icons.check : icon,
                    color: fg,
                    size: 16,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: state == _RowState.idle
                    ? ReportPalette.inkSecondary
                    : ReportPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
