/// Punto de buceo (tabla Place) con nº de inmersiones del owner.
library;

class DiveSite {
  final int id;
  final String? name;
  final String? country;
  final String? region;
  final String? waterName; // "stretch of water"
  final double? lat;
  final double? lon;
  final double? maxDepth;
  final String? difficulty;
  final int? rating;
  final int diveCount;
  final List<String> tags; // tags asignados al sitio

  const DiveSite({
    required this.id,
    this.name,
    this.country,
    this.region,
    this.waterName,
    this.lat,
    this.lon,
    this.maxDepth,
    this.difficulty,
    this.rating,
    this.diveCount = 0,
    this.tags = const [],
  });

  bool get hasCoords => lat != null && lon != null;
}
