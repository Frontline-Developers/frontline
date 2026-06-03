import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'report_theme.dart';

class SuccessScreen extends StatefulWidget {
  final String token;
  final VoidCallback onDone;
  final VoidCallback onNewReport;
  const SuccessScreen({
    super.key,
    required this.token,
    required this.onDone,
    required this.onNewReport,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ReportPalette.verifiedSoft,
              ),
              child: const Icon(
                Icons.check_circle,
                color: ReportPalette.verified,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Report submitted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: ReportPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your report is in the community verification queue. It will '
            'appear on the feed once 5 other people have viewed it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: ReportPalette.inkSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ReportPalette.raised,
              border: Border.all(color: ReportPalette.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR TRACKING TOKEN',
                  style: ReportTextStyles.sectionLabel,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ReportPalette.card,
                    border: Border.all(
                      color: ReportPalette.hairlineStrong,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.token, style: ReportTextStyles.mono),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.token));
                    if (!mounted) return;
                    setState(() => _copied = true);
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                  label: Text(_copied ? 'Copied' : 'Copy token'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ReportPalette.ink,
                    side: const BorderSide(color: ReportPalette.hairline),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "This is your only link to the report. We can't recover it "
                  "for you — there's nothing to recover from.",
                  style: TextStyle(
                    fontSize: 11,
                    color: ReportPalette.inkTertiary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onDone,
            icon: const Icon(Icons.home_outlined, size: 16),
            label: const Text('Back to feed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ReportPalette.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onNewReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: ReportPalette.ink,
              side: const BorderSide(color: ReportPalette.hairline),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit another report'),
          ),
        ],
      ),
    );
  }
}
