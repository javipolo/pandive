/// When applying a dive type that brings cylinders, discards the existing
/// "empty" cylinders (no start/end pressures) and adds the type's.
library;

import 'package:pandive/core/models/models.dart';

bool tankHasPressure(Cylinder c) =>
    (c.pressureStart ?? 0) > 0 || (c.pressureEnd ?? 0) > 0;

/// Resulting cylinders when picking a type: if the type brings none, it
/// touches nothing; if it does, keeps only the existing ones with pressures and adds
/// the type's (the newly created empty ones are discarded).
List<Cylinder> applyDiveTypeTanks(
    List<Cylinder> existing, List<Cylinder> typeTanks) {
  if (typeTanks.isEmpty) return existing;
  return [...existing.where(tankHasPressure), ...typeTanks];
}
