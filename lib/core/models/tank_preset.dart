/// Preajuste de botella reutilizable ("mis botellas"): litros + material.
library;

import 'cylinder.dart';

class TankPreset {
  final int id;
  final String name;
  final double litres;
  final TankMaterial material;

  const TankPreset({
    required this.id,
    required this.name,
    required this.litres,
    required this.material,
  });
}
