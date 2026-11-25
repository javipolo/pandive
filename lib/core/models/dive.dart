/// Dive (Logbook row in the .ddb). Only the fields the app uses.
library;

class Dive {
  final int id; // Logbook.ID
  final int? number; // Logbook.Number
  final DateTime? date; // Divedate + Entrytime
  final String? place; // Logbook.Place (denormalised text)
  final String? country; // Logbook.Country
  final int? placeId; // Logbook.PlaceID -> Place.ID
  final double? durationMin; // Logbook.Divetime (minutes)
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
  final int? deco; // Logbook.Deco (1=deco, 0=no deco)
  final double? o2; // Logbook.O2 (% of the main mix)

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
    this.deco,
    this.o2,
  });
}
