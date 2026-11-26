/// Departure/arrival port (own table PandivePort): name + optional GPS. Used
/// by trips (departure and arrival) and, optionally, by single dives (the
/// port the boat left from).
library;

class Port {
  final int id;
  final String name;
  final double? lat;
  final double? lon;
  final int useCount; // dives + trips that use it

  const Port({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
    this.useCount = 0,
  });

  bool get hasCoords => lat != null && lon != null;
}
