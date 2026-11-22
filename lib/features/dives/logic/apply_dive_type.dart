/// Al aplicar un tipo de buceo que aporta botellas, descarta las botellas
/// existentes "vacías" (sin presiones de entrada/salida) y añade las del tipo.
library;

import 'package:pandive/core/models/models.dart';

bool tankHasPressure(Cylinder c) =>
    (c.pressureStart ?? 0) > 0 || (c.pressureEnd ?? 0) > 0;

/// Botellas resultantes al elegir un tipo: si el tipo no aporta ninguna, no
/// toca nada; si aporta, conserva solo las existentes con presiones y añade las
/// del tipo (las vacías recién creadas se descartan).
List<Cylinder> applyDiveTypeTanks(
    List<Cylinder> existing, List<Cylinder> typeTanks) {
  if (typeTanks.isEmpty) return existing;
  return [...existing.where(tankHasPressure), ...typeTanks];
}
