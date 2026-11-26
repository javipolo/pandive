/// When applying a dive type that brings cylinders, discards the existing
/// "empty" cylinders (no start/end pressures) and adds the type's, except
/// those already present (same size and material) among the filled ones.
library;

import 'package:pandive/core/models/models.dart';

bool tankHasPressure(Cylinder c) =>
    (c.pressureStart ?? 0) > 0 || (c.pressureEnd ?? 0) > 0;

/// Same cylinder "kind": same litres (±0.05) and, when both know it, the same
/// material (an unknown material matches any).
bool sameTankKind(Cylinder a, Cylinder b) {
  if (a.size == null || b.size == null) return false;
  if ((a.size! - b.size!).abs() > 0.05) return false;
  return a.material == null || b.material == null || a.material == b.material;
}

/// Resulting cylinders when picking a type: if the type brings none, it
/// touches nothing; if it does, keeps only the existing ones with pressures and
/// adds the type's that aren't already covered by one of them (each existing
/// cylinder covers at most one template cylinder). E.g. a dive with 2×11.1 L
/// filled + type "Sidemount" (2×11.1 L) stays with its 2 cylinders.
List<Cylinder> applyDiveTypeTanks(
    List<Cylinder> existing, List<Cylinder> typeTanks) {
  if (typeTanks.isEmpty) return existing;
  final kept = existing.where(tankHasPressure).toList();
  final free = [...kept];
  final added = <Cylinder>[];
  for (final t in typeTanks) {
    final i = free.indexWhere((c) => sameTankKind(c, t));
    if (i >= 0) {
      free.removeAt(i);
    } else {
      added.add(t);
    }
  }
  return [...kept, ...added];
}
