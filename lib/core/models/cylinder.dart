/// Botella/mezcla de una inmersión (tabla Tank).
library;

enum TankMaterial { aluminium, steel }

class Cylinder {
  final double? size; // litros
  final double? pressureStart; // bar
  final double? pressureEnd; // bar
  final double? o2; // % oxígeno
  final double? he; // % helio
  final String? name;
  final TankMaterial? material;

  const Cylinder({
    this.size,
    this.pressureStart,
    this.pressureEnd,
    this.o2,
    this.he,
    this.name,
    this.material,
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
