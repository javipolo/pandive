/// Planificación de gas: dado un consumo (RMV, l/min en superficie), una
/// profundidad y tiempo medios, y una configuración de botellas (litros totales
/// + presión inicial), calcula el gas necesario, la caída de presión, la presión
/// final y el tiempo máximo respetando una reserva.
///
///   gas_necesario(L sup) = RMV · tiempo · (prof/10 + 1)
///   ΔP(bar)             = gas_necesario / litros_totales
///   presión_final       = presión_inicial − ΔP
library;

/// Modo de reserva (umbral "verde" de presión final, por botella).
enum ReserveRule { bar35, bar50, thirds, quarters, custom }

/// Reserva en bar para una regla dada. Tercios = 1/3 de la presión inicial;
/// cuartos = 1/2 (regla conservadora de cueva). Fijas: 35/50 bar. Custom: valor
/// introducido. Devuelve null si falta el dato necesario.
double? reserveBarFor(
  ReserveRule rule, {
  required double? startBar,
  double? custom,
}) {
  switch (rule) {
    case ReserveRule.bar35:
      return 35;
    case ReserveRule.bar50:
      return 50;
    case ReserveRule.thirds:
      return startBar == null ? null : startBar / 3.0;
    case ReserveRule.quarters:
      return startBar == null ? null : startBar / 2.0;
    case ReserveRule.custom:
      return custom;
  }
}

class GasPlan {
  final double gasNeededL; // litros en superficie para el buceo planeado
  final double deltaBar; // caída de presión sobre la configuración
  final double endBar; // presión al terminar
  final double reserveBar; // reserva mínima objetivo
  final double maxTimeMin; // tiempo máx. hasta tocar la reserva

  const GasPlan({
    required this.gasNeededL,
    required this.deltaBar,
    required this.endBar,
    required this.reserveBar,
    required this.maxTimeMin,
  });

  /// true si al terminar aún queda al menos la reserva.
  bool get ok => endBar >= reserveBar;

  /// Bar por encima (si +) o por debajo (si −) de la reserva al terminar.
  double get marginBar => endBar - reserveBar;
}

GasPlan? computeGasPlan({
  required double? rmv,
  required double? avgDepthM,
  required double? timeMin,
  required double? totalLitres,
  required double? startBar,
  required double? reserveBar,
}) {
  if (rmv == null || rmv <= 0) return null;
  if (avgDepthM == null || avgDepthM <= 0) return null;
  if (timeMin == null || timeMin <= 0) return null;
  if (totalLitres == null || totalLitres <= 0) return null;
  if (startBar == null || startBar <= 0) return null;
  final reserve = (reserveBar == null || reserveBar < 0) ? 0.0 : reserveBar;

  final ata = avgDepthM / 10.0 + 1.0;
  final gasNeeded = rmv * timeMin * ata;
  final delta = gasNeeded / totalLitres;
  final end = startBar - delta;

  final usableBar = startBar - reserve;
  final usableL = usableBar > 0 ? usableBar * totalLitres : 0.0;
  final maxTime = usableL > 0 ? usableL / (rmv * ata) : 0.0;

  return GasPlan(
    gasNeededL: gasNeeded,
    deltaBar: delta,
    endBar: end,
    reserveBar: reserve,
    maxTimeMin: maxTime,
  );
}
