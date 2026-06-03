import 'dart:io';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/reporting_provider.dart';
import 'report_theme.dart';

class StepEvidence extends ConsumerStatefulWidget {
  const StepEvidence({super.key});

  @override
  ConsumerState<StepEvidence> createState() => _StepEvidenceState();
}

class _StepEvidenceState extends ConsumerState<StepEvidence>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final AnimationController _stripAnim;
  List<(String, String)> _exifRows = [];

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
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Read from original path on mobile to preserve EXIF before any re-encoding.
    // On web XFile.path is a blob URL so we fall back to readAsBytes().
    final Uint8List rawBytes;
    if (!kIsWeb) {
      rawBytes = await File(picked.path).readAsBytes();
    } else {
      rawBytes = await picked.readAsBytes();
    }

    if (!mounted) return;

    // Extract EXIF from full-res bytes first, then compress before storing
    // so the draft never holds a multi-megabyte raw image in RAM.
    final rows = await _extractExifRows(rawBytes);
    final compressed = await FlutterImageCompress.compressWithList(
      rawBytes,
      quality: 88,
      keepExif: false,
    );
    if (!mounted) return;

    setState(() => _exifRows = rows);
    _stripAnim.value = 0;
    ref
        .read(reportingNotifierProvider.notifier)
        .updateDraft(mediaBytes: [compressed]);
    _stripAnim.forward();
  }

  static Future<List<(String, String)>> _extractExifRows(
    Uint8List bytes,
  ) async {
    try {
      final data = await readExifFromBytes(bytes);
      if (data.isEmpty) return [];

      final rows = <(String, String)>[];

      final latRef = data['GPS GPSLatitudeRef']?.printable;
      final lat = data['GPS GPSLatitude']?.printable;
      final lngRef = data['GPS GPSLongitudeRef']?.printable;
      final lng = data['GPS GPSLongitude']?.printable;
      if (lat != null && lng != null) {
        rows.add(('GPS', '$lat ${latRef ?? ''}, $lng ${lngRef ?? ''}'.trim()));
      }

      final make = data['Image Make']?.printable.trim();
      final model = data['Image Model']?.printable.trim();
      if (make != null || model != null) {
        rows.add(('Device', [make, model].whereType<String>().join(' ')));
      }

      final ts =
          data['EXIF DateTimeOriginal']?.printable ??
          data['Image DateTime']?.printable;
      if (ts != null) rows.add(('Timestamp', ts));

      final serial =
          data['EXIF BodySerialNumber']?.printable ??
          data['EXIF CameraSerialNumber']?.printable;
      if (serial != null && serial.trim().isNotEmpty) {
        rows.add(('Camera serial', serial.trim()));
      }

      return rows;
    } catch (e, st) {
      assert(() {
        debugPrint('EXIF read failed: $e\n$st');
        return true;
      }());
      return [];
    }
  }

  void _removePhoto() {
    ref.read(reportingNotifierProvider.notifier).updateDraft(mediaBytes: []);
    setState(() => _exifRows = []);
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
              'Add photo',
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
          AnimatedBuilder(
            animation: _stripAnim,
            builder: (context, _) {
              if (_stripAnim.value < 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_exifRows.isNotEmpty) ...[
                      const Text(
                        'METADATA REMOVED',
                        style: ReportTextStyles.sectionLabel,
                      ),
                      const SizedBox(height: 8),
                      ..._exifRows.map(
                        (r) => _ExifRow(label: r.$1, value: r.$2),
                      ),
                    ] else ...[
                      const Text(
                        'METADATA',
                        style: ReportTextStyles.sectionLabel,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No metadata found in this image',
                        style: TextStyle(
                          color: ReportPalette.inkTertiary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExifRow extends StatelessWidget {
  final String label;
  final String value;
  const _ExifRow({required this.label, required this.value});

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
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ReportPalette.ink,
                fontSize: 11,
                fontFamily: 'monospace',
                decoration: TextDecoration.lineThrough,
                decorationThickness: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
