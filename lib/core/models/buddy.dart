/// Compañero de buceo (tabla Buddy). Solo guardamos el nombre.
library;

class Buddy {
  final int id;
  final String name;
  final int diveCount;
  final DateTime? lastDive; // fecha del buceo más reciente con este buddy

  const Buddy({
    required this.id,
    required this.name,
    this.diveCount = 0,
    this.lastDive,
  });
}
