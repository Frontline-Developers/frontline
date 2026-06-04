enum MapTimeRange { hour, sixHours, day, all }

enum MapCategory { all, combat, aid, alert, displaced, infra, other }

class MapFilters {
  final MapTimeRange timeRange;
  final MapCategory category;

  const MapFilters({
    this.timeRange = MapTimeRange.sixHours,
    this.category = MapCategory.all,
  });

  bool get isDefault =>
      timeRange == MapTimeRange.sixHours && category == MapCategory.all;

  MapFilters copyWith({MapTimeRange? timeRange, MapCategory? category}) {
    return MapFilters(
      timeRange: timeRange ?? this.timeRange,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapFilters &&
          timeRange == other.timeRange &&
          category == other.category;

  @override
  int get hashCode => Object.hash(timeRange, category);
}
