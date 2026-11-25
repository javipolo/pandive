/// Dive buddy (Buddy table). We only store the name.
library;

class Buddy {
  final int id;
  final String name;
  final int diveCount;
  final DateTime? lastDive; // date of the most recent dive with this buddy

  const Buddy({
    required this.id,
    required this.name,
    this.diveCount = 0,
    this.lastDive,
  });
}
