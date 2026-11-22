class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.archived,
    this.lastAtMs,
    this.lastOffset,
    this.locationId,
    this.locationName,
  });
  final int id;
  final String name;
  final bool archived;
  final int? lastAtMs;
  final int? lastOffset;
  final int? locationId;
  final String? locationName;
}

class Location {
  const Location({required this.id, required this.name});
  final int id;
  final String name;
}

class SplitDay {
  const SplitDay({required this.id, required this.name});
  final int id;
  final String name;
}
