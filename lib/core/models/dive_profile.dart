/// Perfil muestreado de una inmersión (profundidad y, si existe, temperatura).
library;

class DiveProfile {
  final int intervalSeconds;
  final List<double> timesMinutes;
  final List<double> depths; // metros
  final List<double?> temps; // °C, null donde no hay muestra

  const DiveProfile({
    required this.intervalSeconds,
    required this.timesMinutes,
    required this.depths,
    required this.temps,
  });

  bool get hasTemp => temps.any((t) => t != null);
  bool get isEmpty => depths.isEmpty;
}
