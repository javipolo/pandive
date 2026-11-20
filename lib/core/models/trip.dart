/// Un viaje de buceo: agrupa inmersiones (y opcionalmente compañeros).
library;

class Trip {
  final int id;
  final String name;
  final int diveCount;
  final int buddyCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
  const Trip({
    required this.id,
    required this.name,
    this.diveCount = 0,
    this.buddyCount = 0,
    this.firstDate,
    this.lastDate,
  });
}
