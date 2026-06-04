import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/reporting_provider.dart';
import '../widgets/processing_screen.dart';
import '../widgets/report_theme.dart';
import '../widgets/step_describe.dart';
import '../widgets/step_evidence.dart';
import '../widgets/step_location.dart';
import '../widgets/success_screen.dart';

class ReportingScreen extends ConsumerWidget {
  const ReportingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportingNotifierProvider);

    Widget body;
    switch (state.stage) {
      case ReportingStage.processing:
        body = ProcessingScreen(step: state.processingStep);
        break;
      case ReportingStage.success:
        body = SuccessScreen(
          token: state.displayToken ?? '',
          onDone: () {
            ref.read(reportingNotifierProvider.notifier).reset();
            if (context.canPop()) context.pop();
          },
          onNewReport: () =>
              ref.read(reportingNotifierProvider.notifier).reset(),
        );
        break;
      case ReportingStage.describe:
      case ReportingStage.location:
      case ReportingStage.evidence:
        body = _FormShell(state: state);
        break;
    }

    return Scaffold(
      backgroundColor: ReportPalette.surface,
      body: SafeArea(child: body),
    );
  }
}

class _FormShell extends ConsumerWidget {
  final ReportingState state;
  const _FormShell({required this.state});

  int get _stepNumber {
    switch (state.stage) {
      case ReportingStage.describe:
        return 1;
      case ReportingStage.location:
        return 2;
      case ReportingStage.evidence:
        return 3;
      default:
        return 1;
    }
  }

  String get _title {
    switch (state.stage) {
      case ReportingStage.describe:
        return 'What did you see?';
      case ReportingStage.location:
        return 'Where, roughly?';
      case ReportingStage.evidence:
        return 'Evidence';
      default:
        return '';
    }
  }

  bool _canContinue() {
    switch (state.stage) {
      case ReportingStage.describe:
        return state.draft.isDescribeValid;
      case ReportingStage.location:
        return state.draft.isLocationValid;
      case ReportingStage.evidence:
        return state.draft.isEvidenceValid;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reportingNotifierProvider.notifier);
    final isLastStep = state.stage == ReportingStage.evidence;

    Widget current;
    switch (state.stage) {
      case ReportingStage.describe:
        current = const StepDescribe();
        break;
      case ReportingStage.location:
        current = const StepLocation();
        break;
      case ReportingStage.evidence:
        current = const StepEvidence();
        break;
      default:
        current = const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            ref
                                .read(reportingNotifierProvider.notifier)
                                .reset();
                            if (context.canPop()) context.pop();
                          },
                          icon: const Icon(
                            Icons.close,
                            color: ReportPalette.ink,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_user,
                          color: ReportPalette.navy,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Anonymous report',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ReportPalette.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_title, style: ReportTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Step $_stepNumber of 3 · no account, no tracking',
                      style: ReportTextStyles.subtitle,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(3, (i) {
                        final filled = i < _stepNumber;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: filled
                                  ? ReportPalette.navy
                                  : ReportPalette.overlay,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    current,
                    if (state.error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEEBEB),
                          border: Border.all(color: ReportPalette.disputed),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: ReportPalette.disputed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: ReportPalette.disputed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (state.stage != ReportingStage.describe)
                          SizedBox(
                            width: 90,
                            child: OutlinedButton(
                              onPressed: notifier.back,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ReportPalette.ink,
                                side: const BorderSide(
                                  color: ReportPalette.hairline,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        if (state.stage != ReportingStage.describe)
                          const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _canContinue()
                                ? (isLastStep ? notifier.submit : notifier.next)
                                : null,
                            icon: Icon(
                              isLastStep
                                  ? Icons.verified_user
                                  : Icons.arrow_forward,
                              size: 16,
                            ),
                            label: Text(
                              isLastStep ? 'Strip & submit' : 'Continue',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ReportPalette.navy,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: ReportPalette.overlay,
                              disabledForegroundColor:
                                  ReportPalette.inkTertiary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ReportPalette.raised,
                        border: Border.all(color: ReportPalette.hairlineSoft),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 22,
                            color: ReportPalette.navy,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Privacy by design',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: ReportPalette.ink,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'No login. No account. No IP logged. Photos stripped of EXIF before upload. GPS randomized ±3km. You\'ll get a token to track your report — that token isn\'t linked to you.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: ReportPalette.inkSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
