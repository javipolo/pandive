/// Sampled profile of a dive (depth and, if present, temperature).
library;

class DiveProfile {
  final int intervalSeconds;
  final List<double> timesMinutes;
  final List<double> depths; // metros
  final List<double?> temps; // °C, null where there is no sample
  final List<double> ceiling; // deco ceiling (m), 0 if none (aligned)
  final List<int?> ndl; // no-deco min (null in deco)
  final List<int?> tts; // min to surface (null out of deco)
  final List<double?> ppo2; // bar
  final List<double?> cns; // %
  final List<double?> pressure; // cylinder pressure (bar)
  final List<int?> rbt; // min

  const DiveProfile({
    required this.intervalSeconds,
    required this.timesMinutes,
    required this.depths,
    required this.temps,
    this.ceiling = const [],
    this.ndl = const [],
    this.tts = const [],
    this.ppo2 = const [],
    this.cns = const [],
    this.pressure = const [],
    this.rbt = const [],
  });

  bool get hasTemp => temps.any((t) => t != null);
  bool get hasDeco => ceiling.any((c) => c > 0);
  bool get isEmpty => depths.isEmpty;
}
