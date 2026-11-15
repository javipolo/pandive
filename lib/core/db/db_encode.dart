part of 'divemate_db.dart';

String _p3(int v) => v.clamp(0, 999).toString().padLeft(3, '0');

/// Codifica las muestras al formato DiveMate: Profile (12 chars/muestra, 4
/// primeros = decímetros), Profile2 (11 chars, 4 primeros = centi-°C), e
/// intervalo en segundos. Asume muestreo uniforme (como el ordenador).
(int, String?, String?) _encodeProfile(List<DiveSample> samples) {
  if (samples.length < 2) return (0, null, null);
  final totalMs = samples.last.timeMs - samples.first.timeMs;
  var interval = (totalMs / (samples.length - 1) / 1000).round();
  if (interval <= 0) interval = 10;

  final prof = StringBuffer();
  final prof2 = StringBuffer();
  for (final s in samples) {
    final dm = (s.depth * 10).round().clamp(0, 9999);
    prof.write(dm.toString().padLeft(4, '0'));
    prof.write('00000000'); // 12 chars por registro
    final centi = s.temp != null ? (s.temp! * 100).round().clamp(0, 9999) : 0;
    prof2.write(centi.toString().padLeft(4, '0'));
    prof2.write('0000000'); // 11 chars por registro
  }
  return (interval, prof.toString(), prof2.toString());
}

/// Codifica Profile4 (formato DiveMate: NDL/TTS/parada + techo) desde muestras.
/// Devuelve null si no hay datos de deco/NDL.
String? _encodeProfile4(List<DiveSample> samples) {
  final any = samples.any((s) => s.ceiling > 0 || s.ndl != null || s.tts != null);
  if (!any) return null;
  final b = StringBuffer();
  for (final s in samples) {
    if (s.ceiling > 0) {
      b..write(_p3(s.tts ?? 0))..write('000')..write(_p3(s.ceiling.round()));
    } else {
      final n = s.ndl ?? 0;
      b..write(_p3(n))..write(_p3(n))..write('000');
    }
  }
  return b.toString();
}
