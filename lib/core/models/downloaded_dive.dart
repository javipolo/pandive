/// Inmersión descargada del ordenador (parseada por libdivecomputer, vía JSON).
library;

class DiveSample {
  final int timeMs;
  final double depth;
  final double? temp;
  final int? ndl; // min sin deco
  final int? tts; // min hasta superficie (en deco)
  final double ceiling; // techo de deco (m), 0 si ninguno
  final int? gasIndex; // mezcla activa (índice), null si desconocido
  final double? ppo2; // bar
  final double? cns; // %
  final double? pressure; // presión de botella (bar), AI
  final int? rbt; // tiempo de fondo restante (min), AI
  const DiveSample(this.timeMs, this.depth, this.temp,
      {this.ndl,
      this.tts,
      this.ceiling = 0,
      this.gasIndex,
      this.ppo2,
      this.cns,
      this.pressure,
      this.rbt});
}

class GasMix {
  final double o2; // fracción 0-1
  final double he;
  const GasMix(this.o2, this.he);
}

class DownloadedDive {
  final String fingerprint;
  final DateTime? datetime;
  final int? divetimeSec;
  final double? maxDepth;
  final double? avgDepth;
  final double? tempMin;
  final List<GasMix> gasmixes;
  final List<DiveSample> samples;

  const DownloadedDive({
    required this.fingerprint,
    this.datetime,
    this.divetimeSec,
    this.maxDepth,
    this.avgDepth,
    this.tempMin,
    this.gasmixes = const [],
    this.samples = const [],
  });

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'datetime': datetime?.toIso8601String(),
        'divetime': divetimeSec,
        'maxdepth': maxDepth,
        'avgdepth': avgDepth,
        'tempmin': tempMin,
        'gasmixes': [for (final g in gasmixes) {'o2': g.o2, 'he': g.he}],
        'samples': [
          for (final s in samples)
            [s.timeMs, s.depth, s.temp, s.ndl, s.tts, s.ceiling, s.gasIndex,
              s.ppo2, s.cns, s.pressure, s.rbt],
        ],
      };

  factory DownloadedDive.fromJson(Map<String, dynamic> j) {
    return DownloadedDive(
      fingerprint: (j['fingerprint'] ?? '') as String,
      datetime: j['datetime'] != null ? DateTime.tryParse(j['datetime']) : null,
      divetimeSec: (j['divetime'] as num?)?.toInt(),
      maxDepth: (j['maxdepth'] as num?)?.toDouble(),
      avgDepth: (j['avgdepth'] as num?)?.toDouble(),
      tempMin: (j['tempmin'] as num?)?.toDouble(),
      gasmixes: [
        for (final g in (j['gasmixes'] as List? ?? []))
          GasMix((g['o2'] as num).toDouble(), (g['he'] as num).toDouble()),
      ],
      samples: [
        for (final s in (j['samples'] as List? ?? []))
          DiveSample(
            (s[0] as num).toInt(),
            (s[1] as num).toDouble(),
            s[2] == null ? null : (s[2] as num).toDouble(),
            ndl: s.length > 3 && s[3] != null ? (s[3] as num).toInt() : null,
            tts: s.length > 4 && s[4] != null ? (s[4] as num).toInt() : null,
            ceiling: s.length > 5 && s[5] != null ? (s[5] as num).toDouble() : 0,
            gasIndex: s.length > 6 && s[6] != null ? (s[6] as num).toInt() : null,
            ppo2: s.length > 7 && s[7] != null ? (s[7] as num).toDouble() : null,
            cns: s.length > 8 && s[8] != null ? (s[8] as num).toDouble() : null,
            pressure:
                s.length > 9 && s[9] != null ? (s[9] as num).toDouble() : null,
            rbt: s.length > 10 && s[10] != null ? (s[10] as num).toInt() : null,
          ),
      ],
    );
  }
}

/// Resultado de una descarga: inmersiones o un error.
class DownloadResult {
  final List<DownloadedDive> dives;
  final String? error;
  const DownloadResult({this.dives = const [], this.error});

  bool get ok => error == null;
}
