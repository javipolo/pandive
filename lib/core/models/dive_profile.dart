/// Perfil muestreado de una inmersión (profundidad y, si existe, temperatura).
library;

class DiveProfile {
  final int intervalSeconds;
  final List<double> timesMinutes;
  final List<double> depths; // metros
  final List<double?> temps; // °C, null donde no hay muestra
  final List<double> ceiling; // techo de deco (m), 0 si no hay (alineado)
  final List<int?> ndl; // min sin deco (null en deco)
  final List<int?> tts; // min hasta superficie (null fuera de deco)

  const DiveProfile({
    required this.intervalSeconds,
    required this.timesMinutes,
    required this.depths,
    required this.temps,
    this.ceiling = const [],
    this.ndl = const [],
    this.tts = const [],
  });

  bool get hasTemp => temps.any((t) => t != null);
  bool get hasDeco => ceiling.any((c) => c > 0);
  bool get isEmpty => depths.isEmpty;
}
