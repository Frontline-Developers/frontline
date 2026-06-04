import '../entities/alert_subscription.dart';
import '../repositories/alert_repository.dart';

/// Validates inputs and delegates to [AlertRepository.save].
/// Throws [ArgumentError] on invalid input — never calls the repo.
class SaveAlert {
  final AlertRepository _repository;
  const SaveAlert(this._repository);

  Future<String> call({
    required String userId,
    required String locationLabel,
    required double lat,
    required double lng,
    required double radiusKm,
    required List<String> categories,
  }) {
    if (categories.isEmpty) {
      throw ArgumentError.value(
        categories,
        'categories',
        'Must select at least one category',
      );
    }
    if (radiusKm < 1 || radiusKm > 20) {
      throw ArgumentError.value(
        radiusKm,
        'radiusKm',
        'Radius must be between 1 and 20 km',
      );
    }

    final subscription = AlertSubscription(
      id: '',
      userId: userId,
      locationLabel: locationLabel,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      categories: List.unmodifiable(categories),
      createdAt: DateTime.now(),
    );

    return _repository.save(subscription);
  }
}
