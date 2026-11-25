/// Summary data of a dive (duration, depths, minimum
/// temperature, deco) from the record and, if something is missing, the profile. Used by
/// the dive detail and the exported chart image.
library;

import 'package:pandive/core/models/models.dart';

class DiveFacts {
  final double? durationMin;
  final double? maxDepth; // m
  final double? avgDepth; // m
  final double? minTemp; // °C
  final bool isDeco;
  final int? maxTts; // min
  final double? maxCeiling; // m
  final double? ceilingMinutes; // time under a ceiling

  const DiveFacts({
    this.durationMin,
    this.maxDepth,
    this.avgDepth,
    this.minTemp,
    this.isDeco = false,
    this.maxTts,
    this.maxCeiling,
    this.ceilingMinutes,
  });

  factory DiveFacts.of(Dive dive, DiveProfile? profile) {
    final temps = profile?.temps.whereType<double>() ?? const <double>[];
    final depths = profile?.depths ?? const <double>[];
    final isDeco = dive.deco == 1 || (profile?.hasDeco ?? false);
    var maxTts = 0;
    var maxCeiling = 0.0;
    var ceilSamples = 0;
    if (isDeco && profile != null) {
      for (final c in profile.ceiling) {
        if (c > 0) {
          ceilSamples++;
          if (c > maxCeiling) maxCeiling = c;
        }
      }
      for (final x in profile.tts) {
        if (x != null && x > maxTts) maxTts = x;
      }
    }
    return DiveFacts(
      durationMin: dive.durationMin,
      maxDepth: dive.maxDepth ??
          (depths.isEmpty ? null : depths.reduce((a, b) => a > b ? a : b)),
      avgDepth: dive.avgDepth ?? _avg(depths.where((d) => d > 0)),
      minTemp: dive.waterTemp ??
          (temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b)),
      isDeco: isDeco,
      maxTts: maxTts > 0 ? maxTts : null,
      maxCeiling: maxCeiling > 0 ? maxCeiling : null,
      ceilingMinutes: ceilSamples > 0
          ? ceilSamples * profile!.intervalSeconds / 60.0
          : null,
    );
  }
}

double? _avg(Iterable<double> xs) {
  final l = xs.toList();
  return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
}
