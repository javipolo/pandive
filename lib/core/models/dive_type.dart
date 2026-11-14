/// Tipo de buceo configurable: nombre + plantilla de botellas que se añaden
/// automáticamente al elegirlo (p.ej. Sidemount → 2×11.1 L).
library;

import 'cylinder.dart';

class DiveType {
  final int id;
  final String name;
  final List<Cylinder> tanks; // plantilla (litros + material)

  const DiveType({
    required this.id,
    required this.name,
    this.tanks = const [],
  });
}
