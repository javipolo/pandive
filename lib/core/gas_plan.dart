/// Gas planning with a cylinder list (different sizes) and a per-cylinder
/// flag for whether it keeps a reserve or is emptied (stage). Initial pressure and rule of
/// shared reserve.
///
///   needed_gas(L)    = RMV · time · (depth/10 + 1)
///   total_gas(L)     = Σ(litres · initial_pressure)             (all)
///   reserve_exit     = (total_gas − needed_gas) / Σ reserve litres
///   threshold X      = reserve(L) / Σ reserve litres
///
/// Reserve in litres: thirds = 1/3 of total gas; quarters = 1/2; fixed
/// (35/50/custom) = those bar in the reserve cylinders. If no cylinder is
/// marked as reserve, all are treated as reserve.
library;

/// Reserve rule ("green" exit-pressure threshold).
enum ReserveRule { bar35, bar50, thirds, quarters, custom }

class PlanCylinder {
  final double litres;
  final bool keepsReserve; // true = keeps reserve; false = emptied (stage)
  const PlanCylinder(this.litres, {this.keepsReserve = true});
}

class GasPlan {
  final double gasNeededL; // surface litres of the planned dive
  final double endReserveBar; // exit pressure in the reserve cylinders
  final double reserveThresholdBar; // threshold X (bar in the reserve ones)
  final double maxTimeMin; // max time keeping the reserve
  final bool hasStages; // there are cylinders that get emptied

  const GasPlan({
    required this.gasNeededL,
    required this.endReserveBar,
    required this.reserveThresholdBar,
    required this.maxTimeMin,
    required this.hasStages,
  });

  bool get ok => endReserveBar >= reserveThresholdBar;
  double get marginBar => endReserveBar - reserveThresholdBar;
}

double _fixedBar(ReserveRule rule, double? custom) {
  switch (rule) {
    case ReserveRule.bar35:
      return 35;
    case ReserveRule.bar50:
      return 50;
    case ReserveRule.custom:
      return custom ?? 0;
    default:
      return 0;
  }
}

GasPlan? computeGasPlan({
  required double? rmv,
  required double? avgDepthM,
  required double? timeMin,
  required List<PlanCylinder> cylinders,
  required double? startBar,
  required ReserveRule rule,
  double? customBar,
}) {
  if (rmv == null || rmv <= 0) return null;
  if (avgDepthM == null || avgDepthM <= 0) return null;
  if (timeMin == null || timeMin <= 0) return null;
  if (startBar == null || startBar <= 0) return null;

  final totalLitres =
      cylinders.fold<double>(0, (s, c) => s + (c.litres > 0 ? c.litres : 0));
  if (totalLitres <= 0) return null;

  // Litres of the reserve cylinders; if there are none, all are reserve.
  var reserveLitres = cylinders.fold<double>(
      0, (s, c) => s + (c.keepsReserve && c.litres > 0 ? c.litres : 0));
  if (reserveLitres <= 0) reserveLitres = totalLitres;
  final hasStages = reserveLitres < totalLitres;

  final ata = avgDepthM / 10.0 + 1.0;
  final gasNeeded = rmv * timeMin * ata;
  final totalGas = totalLitres * startBar;

  final double reserveGas;
  switch (rule) {
    case ReserveRule.thirds:
      reserveGas = totalGas / 3.0;
    case ReserveRule.quarters:
      reserveGas = totalGas / 2.0;
    default:
      reserveGas = _fixedBar(rule, customBar) * reserveLitres;
  }

  final thresholdBar = reserveGas / reserveLitres;
  // The stage is emptied first; the remaining gas stays in the reserve ones.
  final endBar =
      ((totalGas - gasNeeded) / reserveLitres).clamp(double.negativeInfinity,
          startBar);
  final usableGas = totalGas - reserveGas;
  final maxTime = usableGas > 0 ? usableGas / (rmv * ata) : 0.0;

  return GasPlan(
    gasNeededL: gasNeeded,
    endReserveBar: endBar.toDouble(),
    reserveThresholdBar: thresholdBar,
    maxTimeMin: maxTime,
    hasStages: hasStages,
  );
}
