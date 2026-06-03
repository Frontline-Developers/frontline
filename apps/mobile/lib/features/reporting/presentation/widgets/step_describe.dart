import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/report.dart';
import '../providers/reporting_provider.dart';
import 'report_theme.dart';

class StepDescribe extends ConsumerStatefulWidget {
  const StepDescribe({super.key});

  @override
  ConsumerState<StepDescribe> createState() => _StepDescribeState();
}

class _StepDescribeState extends ConsumerState<StepDescribe> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(reportingNotifierProvider).draft;
    _controller = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportingNotifierProvider).draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DESCRIBE WHAT YOU OBSERVED',
          style: ReportTextStyles.sectionLabel,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 6,
          maxLength: 600,
          inputFormatters: [LengthLimitingTextInputFormatter(600)],
          onChanged: (v) => ref
              .read(reportingNotifierProvider.notifier)
              .updateDraft(description: v),
          decoration: InputDecoration(
            hintText:
                'A drone hit the substation on Akademika Pavlova street around 03:42. Power went out across our block.',
            hintStyle: const TextStyle(
              color: ReportPalette.inkTertiary,
              fontSize: 14,
              height: 1.5,
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
            counterText: '',
          ),
          style: const TextStyle(color: ReportPalette.ink, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Builder(
                builder: (_) {
                  final len = _controller.text.trim().length;
                  final under = len < ReportDraft.minDescriptionLength;
                  return Text(
                    under
                        ? '$len / 600 · min ${ReportDraft.minDescriptionLength} characters'
                        : '$len / 600 characters',
                    overflow: TextOverflow.ellipsis,
                    style: ReportTextStyles.micro.copyWith(
                      color: under ? Colors.red.shade600 : null,
                    ),
                  );
                },
              ),
            ),
            const Spacer(),
            const Row(
              children: [
                Icon(
                  Icons.translate,
                  size: 13,
                  color: ReportPalette.inkTertiary,
                ),
                SizedBox(width: 4),
                Text('Multilingual OK', style: ReportTextStyles.micro),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text('CATEGORIZE', style: ReportTextStyles.sectionLabel),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 56,
          ),
          itemCount: reportCategoryStyles.length,
          itemBuilder: (context, i) {
            final c = reportCategoryStyles[i];
            final selected = draft.category == c.category;
            return _CategoryTile(
              style: c,
              selected: selected,
              onTap: () {
                ref
                    .read(reportingNotifierProvider.notifier)
                    .updateDraft(category: c.category);
              },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ReportCategoryStyle style;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ReportPalette.navySoft : ReportPalette.card,
          border: Border.all(
            color: selected ? ReportPalette.navy : ReportPalette.hairlineSoft,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(style.icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                style.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: ReportPalette.ink,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
