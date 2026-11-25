/// Consumption calculation (RMV, which the app calls SAC) in l/min.
///
/// SAC = Σ(ΔP_bar · litres) / (time_min · (avg_depth_m / 10 + 1))
/// Adds up the gas consumed from all cylinders (at 1 bar) and normalises it by
/// time and average ambient pressure.
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

/// SAC in bar/min: (summed) pressure drop normalised by time and average
/// ambient pressure. Independent of cylinder size.
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
