/// Modelos de dominio de Pandive, mapeados desde el esquema DiveMate (.ddb).
/// Solo exponemos los campos que la app usa; el esquema en disco es el completo
/// de DiveMate (ver README).
library;

class Dive {
  final int id; // Logbook.ID
  final int? number; // Logbook.Number
  final DateTime? date; // Divedate + Entrytime
  final String? place; // Logbook.Place (texto desnormalizado)
  final String? country; // Logbook.Country
  final int? placeId; // Logbook.PlaceID -> Place.ID
  final double? durationMin; // Logbook.Divetime (minutos)
  final double? maxDepth; // Logbook.Depth (m)
  final double? avgDepth; // Logbook.DepthAvg (m)
  final double? waterTemp; // Logbook.Watertemp (°C)
  final double? airTemp; // Logbook.Airtemp (°C)
  final double? pressureStart; // Logbook.PresS (bar)
  final double? pressureEnd; // Logbook.PresE (bar)
  final double? weight; // Logbook.Weight (kg)
  final int? rating; // Logbook.Rating (0-5)
  final String? computer; // Logbook.Computer
  final String? buddy; // Logbook.Buddy
  final String? diveMaster; // Logbook.Divemaster
  final String? diveType; // Logbook.Divetype
  final String? comments; // Logbook.Comments
  final String? surfaceInterval; // Logbook.Surfint
  final int? profileInterval; // Logbook.ProfileInt (s)

  const Dive({
    required this.id,
    this.number,
    this.date,
    this.place,
    this.country,
    this.placeId,
    this.durationMin,
    this.maxDepth,
    this.avgDepth,
    this.waterTemp,
    this.airTemp,
    this.pressureStart,
    this.pressureEnd,
    this.weight,
    this.rating,
    this.computer,
    this.buddy,
    this.diveMaster,
    this.diveType,
    this.comments,
    this.surfaceInterval,
    this.profileInterval,
  });
}

/// Perfil muestreado de una inmersión (profundidad y, si existe, temperatura).
class DiveProfile {
  final int intervalSeconds;
  final List<double> timesMinutes;
  final List<double> depths; // metros
  final List<double?> temps; // °C, null donde no hay muestra

  const DiveProfile({
    required this.intervalSeconds,
    required this.timesMinutes,
    required this.depths,
    required this.temps,
  });

  bool get hasTemp => temps.any((t) => t != null);
  bool get isEmpty => depths.isEmpty;
}

/// Punto de buceo (tabla Place) con nº de inmersiones del owner.
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

/// Estadísticas agregadas del logbook (del owner).
class LogbookStats {
  final int totalDives;
  final double totalMinutes;
  final double? avgDiveMinutes;
  final double? maxDepth; // MAX(Depth)
  final double? avgDepth; // AVG(DepthAvg)
  final double? avgWaterTemp;
  final DateTime? firstDive;
  final DateTime? lastDive;
  final Map<int, int> divesPerYear; // año -> nº inmersiones

  const LogbookStats({
    required this.totalDives,
    required this.totalMinutes,
    this.avgDiveMinutes,
    this.maxDepth,
    this.avgDepth,
    this.avgWaterTemp,
    this.firstDive,
    this.lastDive,
    this.divesPerYear = const {},
  });

  double get totalHours => totalMinutes / 60.0;
}

/// Botella/mezcla de una inmersión (tabla Tank).
class Cylinder {
  final double? size; // litros
  final double? pressureStart; // bar
  final double? pressureEnd; // bar
  final double? o2; // % oxígeno
  final double? he; // % helio
  final String? name;

  const Cylinder({
    this.size,
    this.pressureStart,
    this.pressureEnd,
    this.o2,
    this.he,
    this.name,
  });

  /// Nombre de la mezcla: Air / Nitrox EANxx / Trimix.
  String get gasLabel {
    final o = o2;
    final h = he;
    if (o == null || o <= 0) return 'Aire';
    if (h != null && h > 0) return 'Trimix ${o.round()}/${h.round()}';
    if (o.round() == 21) return 'Aire';
    return 'Nitrox EAN${o.round()}';
  }
}
