/// Punto de buceo (tabla Place) con nº de inmersiones del owner.
library;

class DiveSite {
  final int id;
  final String? name;
  final String? country;
  final String? region;
  final double? lat;
  final double? lon;
  final double? maxDepth;
  final int? rating;
  final int diveCount;

  const DiveSite({
    required this.id,
    this.name,
    this.country,
    this.region,
    this.lat,
    this.lon,
    this.maxDepth,
    this.rating,
    this.diveCount = 0,
  });

  bool get hasCoords => lat != null && lon != null;
}
