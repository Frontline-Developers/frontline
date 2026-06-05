import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/reporting_datasource.dart';
import '../../data/repositories/reporting_repository_impl.dart';
import '../../data/services/geocoding_service.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reporting_repository.dart';

export '../../data/services/geocoding_service.dart' show GeocodingService;

enum ReportingStage { describe, location, evidence, processing, success }

class ReportingState {
  final ReportingStage stage;
  final ReportDraft draft;
  final int processingStep; // 0..4 — animated checklist on processing screen
  final String? displayToken;
  final String? reportId;
  final String? error;

  const ReportingState({
    this.stage = ReportingStage.describe,
    this.draft = const ReportDraft(),
    this.processingStep = 0,
    this.displayToken,
    this.reportId,
    this.error,
  });

  ReportingState copyWith({
    ReportingStage? stage,
    ReportDraft? draft,
    int? processingStep,
    Object? displayToken = _sentinel,
    Object? reportId = _sentinel,
    Object? error = _sentinel,
  }) {
    return ReportingState(
      stage: stage ?? this.stage,
      draft: draft ?? this.draft,
      processingStep: processingStep ?? this.processingStep,
      displayToken: displayToken == _sentinel
          ? this.displayToken
          : displayToken as String?,
      reportId: reportId == _sentinel ? this.reportId : reportId as String?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

final geocodingServiceProvider = Provider<GeocodingService>(
  (_) => const GeocodingServiceImpl(),
);

final reportingDatasourceProvider = Provider<ReportingDatasource>(
  (_) => ReportingDatasourceImpl(),
);

final reportingRepositoryProvider = Provider<ReportingRepository>(
  (ref) => ReportingRepositoryImpl(ref.watch(reportingDatasourceProvider)),
);

final reportingNotifierProvider =
    NotifierProvider<ReportingNotifier, ReportingState>(ReportingNotifier.new);

class ReportingNotifier extends Notifier<ReportingState> {
  @override
  ReportingState build() => const ReportingState();

  void updateDraft({
    String? description,
    Object? category = _sentinel,
    String? locationLabel,
    Object? lat = _sentinel,
    Object? lng = _sentinel,
    List<Uint8List>? mediaBytes,
    Object? timeObserved = _sentinel,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        description: description,
        category: category,
        locationLabel: locationLabel,
        lat: lat,
        lng: lng,
        mediaBytes: mediaBytes,
        timeObserved: timeObserved,
      ),
      error: null,
    );
  }

  void next() {
    switch (state.stage) {
      case ReportingStage.describe:
        if (state.draft.isDescribeValid) {
          state = state.copyWith(stage: ReportingStage.location);
        }
        break;
      case ReportingStage.location:
        if (state.draft.isLocationValid) {
          state = state.copyWith(stage: ReportingStage.evidence);
        }
        break;
      case ReportingStage.evidence:
      case ReportingStage.processing:
      case ReportingStage.success:
        break;
    }
  }

  void back() {
    switch (state.stage) {
      case ReportingStage.location:
        state = state.copyWith(stage: ReportingStage.describe);
        break;
      case ReportingStage.evidence:
        state = state.copyWith(stage: ReportingStage.location);
        break;
      case ReportingStage.describe:
      case ReportingStage.processing:
      case ReportingStage.success:
        break;
    }
  }

  Future<void> submit() async {
    state = state.copyWith(
      stage: ReportingStage.processing,
      processingStep: 0,
      error: null,
    );
    try {
      final result = await ref
          .read(reportingRepositoryProvider)
          .submitReport(
            state.draft,
            onProgress: (milestone) {
              // Datasource ticks 1..4 as real pipeline milestones complete
              // (EXIF strip → fuzz CF → uploads → Firestore write).
              state = state.copyWith(processingStep: milestone);
            },
          );
      state = state.copyWith(
        stage: ReportingStage.success,
        displayToken: result.displayToken,
        reportId: result.reportId,
      );
    } catch (e, st) {
      // Log the real error so it's visible in the console during development.
      // The user-facing message stays generic to avoid leaking internal details.
      debugPrint('Report submit failed: $e\n$st');
      state = state.copyWith(
        stage: ReportingStage.evidence,
        error: 'Submit failed. Please try again.',
        processingStep: 0,
      );
    }
  }

  void reset() => state = const ReportingState();
}
