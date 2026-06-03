import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/reporting_provider.dart';
import 'report_theme.dart';

const _exifDemoRows = <(String, String)>[
  ('GPS coordinates', '50.0241°N, 36.2289°E'),
  ('Device', 'iPhone 13 Pro'),
  ('Timestamp', '2025-03-18 03:47:12'),
  ('Camera serial', 'F2LXQK8MNJ29'),
];

class StepEvidence extends ConsumerStatefulWidget {
  const StepEvidence({super.key});

  @override
  ConsumerState<StepEvidence> createState() => _StepEvidenceState();
}

class _StepEvidenceState extends ConsumerState<StepEvidence>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final AnimationController _stripAnim;

  @override
  void initState() {
    super.initState();
    _stripAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final hasExisting = ref
        .read(reportingNotifierProvider)
        .draft
        .mediaBytes
        .isNotEmpty;
    if (hasExisting) _stripAnim.value = 1;
  }

  @override
  void dispose() {
    _stripAnim.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    _stripAnim.value = 0;
    ref
        .read(reportingNotifierProvider.notifier)
        .updateDraft(mediaBytes: [bytes]);
    _stripAnim.forward();
  }

  void _removePhoto() {
    ref.read(reportingNotifierProvider.notifier).updateDraft(mediaBytes: []);
    _stripAnim.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportingNotifierProvider).draft;
    final hasPhoto = draft.mediaBytes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EVIDENCE', style: ReportTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (!hasPhoto) _dropzone() else _preview(draft.mediaBytes.first),
        const SizedBox(height: 22),
        const Text('OPTIONAL CONTEXT', style: ReportTextStyles.sectionLabel),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => ref
              .read(reportingNotifierProvider.notifier)
              .updateDraft(timeObserved: v),
          decoration: InputDecoration(
            hintText: 'Time you observed it (e.g. 03:42 local)',
            hintStyle: const TextStyle(
              color: ReportPalette.inkTertiary,
              fontSize: 14,
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
            contentPadding: const EdgeInsets.all(14),
          ),
          style: const TextStyle(color: ReportPalette.ink, fontSize: 15),
        ),
      ],
    );
  }

  Widget _dropzone() {
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
        decoration: BoxDecoration(
          color: ReportPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ReportPalette.hairlineStrong, width: 2),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              color: ReportPalette.navy,
              size: 36,
            ),
            SizedBox(height: 8),
            Text(
              'Add photo or video',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ReportPalette.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'EXIF metadata (GPS, device, timestamps) is removed before upload',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: ReportPalette.inkSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(Uint8List previewBytes) {
    return Container(
      decoration: BoxDecoration(
        color: ReportPalette.card,
        border: Border.all(color: ReportPalette.hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  previewBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
                AnimatedBuilder(
                  animation: _stripAnim,
                  builder: (context, _) {
                    if (_stripAnim.value >= 1) return const SizedBox.shrink();
                    return Container(
                      color: const Color(0xB30F1117),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'STRIPPING METADATA...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _removePhoto,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x99000000),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedBuilder(
              animation: _stripAnim,
              builder: (context, _) {
                final stripped = _stripAnim.value >= 1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'METADATA REMOVED',
                      style: ReportTextStyles.sectionLabel,
                    ),
                    const SizedBox(height: 8),
                    ..._exifDemoRows.map(
                      (r) => _ExifRow(
                        label: r.$1,
                        value: r.$2,
                        stripped: stripped,
                      ),
                    ),
                    if (stripped) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ReportPalette.verifiedSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              color: ReportPalette.verified,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'All metadata removed locally — server never sees it',
                                style: TextStyle(
                                  color: ReportPalette.verified,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExifRow extends StatelessWidget {
  final String label;
  final String value;
  final bool stripped;
  const _ExifRow({
    required this.label,
    required this.value,
    required this.stripped,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ReportPalette.inkSecondary,
              fontSize: 11.5,
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 500),
            style: TextStyle(
              color: stripped ? ReportPalette.inkTertiary : ReportPalette.ink,
              fontSize: 11,
              fontFamily: 'monospace',
              decoration: stripped
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
