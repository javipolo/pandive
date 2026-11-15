/// Cálculo de consumo (RMV, que en la app llamamos SAC) en l/min.
///
/// SAC = Σ(ΔP_bar · litros) / (tiempo_min · (prof_media_m / 10 + 1))
/// Suma el gas consumido de todas las botellas (a 1 bar) y lo normaliza por
/// tiempo y presión ambiente media.
library;

import 'package:pandive/core/models/models.dart';

double? computeSac(
  List<Cylinder> tanks, {
  required double? divetimeMin,
  required double? avgDepthM,
}) {
  if (divetimeMin == null || divetimeMin <= 0) return null;
  if (avgDepthM == null || avgDepthM <= 0) return null;

  var litresConsumed = 0.0;
  for (final t in tanks) {
    final size = t.size;
    final ps = t.pressureStart;
    final pe = t.pressureEnd;
    if (size == null || ps == null || pe == null) continue;
    final dp = ps - pe;
    if (dp <= 0) continue;
    litresConsumed += dp * size;
  }
  if (litresConsumed <= 0) return null;

  final ata = avgDepthM / 10.0 + 1.0;
  return litresConsumed / (divetimeMin * ata);
}

/// SAC en bar/min: caída de presión (sumada) normalizada por tiempo y presión
/// ambiente media. Independiente del tamaño de la botella.
double? computeSacBar(
  List<Cylinder> tanks, {
  required double? divetimeMin,
  required double? avgDepthM,
}) {
  if (divetimeMin == null || divetimeMin <= 0) return null;
  if (avgDepthM == null || avgDepthM <= 0) return null;
  var dp = 0.0;
  for (final t in tanks) {
    final ps = t.pressureStart, pe = t.pressureEnd;
    if (ps != null && pe != null && ps - pe > 0) dp += ps - pe;
  }
  if (dp <= 0) return null;
  return dp / (divetimeMin * (avgDepthM / 10.0 + 1.0));
}
