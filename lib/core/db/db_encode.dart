part of 'divemate_db.dart';

String _p3(int v) => v.clamp(0, 999).toString().padLeft(3, '0');

/// Encodes samples in DiveMate format: Profile (12 chars/sample, first 4
/// = decimetres), Profile2 (11 chars, first 4 = centi-°C), and
/// interval in seconds. Assumes uniform sampling (like the computer).
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
    prof.write('00000000'); // 12 chars per record
    final centi = s.temp != null ? (s.temp! * 100).round().clamp(0, 9999) : 0;
    prof2.write(centi.toString().padLeft(4, '0'));
    prof2.write('0000000'); // 11 chars per record
  }
  return (interval, prof.toString(), prof2.toString());
}

/// Encodes Profile4 (DiveMate format: NDL/TTS/stop + ceiling) from samples.
/// Returns null if there is no deco/NDL data.
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
