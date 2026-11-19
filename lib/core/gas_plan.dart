/// Planificación de gas con lista de botellas (tamaños distintos) y marca por
/// botella de si mantiene reserva o se vacía (etapa). Presión inicial y regla de
/// reserva compartidas.
///
///   gas_necesario(L) = RMV · tiempo · (prof/10 + 1)
///   gas_total(L)     = Σ(litros · presión_inicial)              (todas)
///   salida_reserva   = (gas_total − gas_necesario) / Σ litros de reserva
///   umbral X         = reserva(L) / Σ litros de reserva
///
/// La reserva en litros: tercios = 1/3 del gas total; cuartos = 1/2; fija
/// (35/50/custom) = esos bar en las botellas de reserva. Si ninguna botella está
/// marcada como reserva, se tratan todas como reserva.
library;

/// Regla de reserva (umbral "verde" de presión de salida).
enum ReserveRule { bar35, bar50, thirds, quarters, custom }

class PlanCylinder {
  final double litres;
  final bool keepsReserve; // true = mantiene reserva; false = se vacía (etapa)
  const PlanCylinder(this.litres, {this.keepsReserve = true});
}

class GasPlan {
  final double gasNeededL; // litros en superficie del buceo planeado
  final double endReserveBar; // presión de salida en las botellas de reserva
  final double reserveThresholdBar; // umbral X (bar en las de reserva)
  final double maxTimeMin; // tiempo máx. respetando la reserva
  final bool hasStages; // hay botellas que se vacían

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

  // Litros de las botellas de reserva; si no hay ninguna, todas son reserva.
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
  // La etapa se vacía primero; el gas restante queda en las de reserva.
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
