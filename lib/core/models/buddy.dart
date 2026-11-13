/// Compañero de buceo (tabla Buddy). Solo guardamos el nombre.
library;

class Buddy {
  final int id;
  final String name;
  final int diveCount;

  const Buddy({required this.id, required this.name, this.diveCount = 0});
}
