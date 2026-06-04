import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/alert_datasource_impl.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/usecases/save_alert.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum AlertStatus { idle, saving, saved, error }

class AlertState {
  final AlertStatus status;
  final String? error;

  const AlertState({this.status = AlertStatus.idle, this.error});

  AlertState copyWith({AlertStatus? status, Object? error = _sentinel}) {
    return AlertState(
      status: status ?? this.status,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// DI
// ---------------------------------------------------------------------------

final _alertDatasourceProvider = Provider(
  (_) => AlertDatasourceImpl(FirebaseFirestore.instance),
);

final _alertRepositoryProvider = Provider(
  (ref) => AlertRepositoryImpl(ref.watch(_alertDatasourceProvider)),
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final alertNotifierProvider = NotifierProvider<AlertNotifier, AlertState>(
  AlertNotifier.new,
);

class AlertNotifier extends Notifier<AlertState> {
  @override
  AlertState build() => const AlertState();

  Future<void> save({
    required String userId,
    required String locationLabel,
    required double lat,
    required double lng,
    required double radiusKm,
    required List<String> categories,
  }) async {
    state = state.copyWith(status: AlertStatus.saving, error: null);
    try {
      await SaveAlert(ref.read(_alertRepositoryProvider))(
        userId: userId,
        locationLabel: locationLabel,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        categories: categories,
      );
      state = state.copyWith(status: AlertStatus.saved, error: null);
    } catch (e) {
      state = state.copyWith(status: AlertStatus.error, error: e.toString());
    }
  }

  void reset() => state = const AlertState();
}
