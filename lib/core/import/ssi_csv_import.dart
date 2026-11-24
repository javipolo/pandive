/// Importa el CSV del logbook que exporta la web de SSI (MySSI). La cabecera
/// va en el idioma del usuario, así que las columnas se leen por posición:
///   0 nº · 1 lugar · 2 país · 3 fecha[/hora] · 4 actividad · 5 especialidad ·
///   6 tipo · 7 duración · 8 profundidad · 9 compañeros/instructor/centro
/// (ver `ssi_csv_fields.dart` para el formato de cada celda).
/// La hora solo viene si el buceador la rellenó en MySSI. Los duplicados se
/// detectan por día + profundidad + duración (+ hora si la hay); las
/// que no traen hora se colocan a las 12:00 (+1 min por cada una que ya
/// ocupe esa hora), en el orden del nº de SSI.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/ssi_csv_fields.dart';

export 'package:pandive/core/import/ssi_csv_fields.dart';

/// Una fila del CSV de SSI ya interpretada.
class SsiDive {
  final int? number;
  final DateTime date; // con hora solo si [hasTime]
  final bool hasTime;
  final String? site;
  final String? country;
  final double? minutes;
  final double? depth; // metros
  final List<String> buddies;
  final List<String> tags; // especialidades, centro, actividad/tipo no habitual
  final String? computer;
  const SsiDive({
    required this.date,
    this.hasTime = false,
    this.number,
    this.site,
    this.country,
    this.minutes,
    this.depth,
    this.buddies = const [],
    this.tags = const [],
    this.computer,
  });
}

/// Resultado de una importación: añadidas, ya existentes y filas ilegibles.
typedef SsiImportResult = ({int added, int duplicates, int skipped});

/// Interpreta el CSV. Devuelve las inmersiones legibles y cuántas filas de
/// datos no se pudieron leer (sin fecha válida). La cabecera se reconoce por
/// no tener fecha y se ignora.
({List<SsiDive> dives, int skipped}) parseSsiCsv(String text) {
  final rows = [
    for (final r in parseCsv(text))
      if (parseSsiDate(r.length > 3 ? r[3] : '') != null) r,
  ];
  final all = parseCsv(text).length;
  // Actividad (col. 4) y tipo (col. 6): el valor que llevan casi todas
  // ("Buceo", "Inmersión de ocio") no aporta; los demás van como etiqueta.
  final usualActivity = _dominant(rows.map((r) => r[4]));
  final usualType = _dominant(rows.map((r) => r.length > 6 ? r[6] : ''));
  final out = <SsiDive>[];
  for (final r in rows) {
    String col(int n) => n < r.length ? r[n] : '';
    final d = parseSsiDate(col(3))!;
    final people = parseSsiPeople(col(9));
    out.add(SsiDive(
      number: int.tryParse(col(0).trim()),
      date: d.date,
      hasTime: d.hasTime,
      site: _clean(col(1)),
      country: _clean(col(2)),
      minutes: parseSsiMinutes(col(7)),
      depth: parseSsiDepth(col(8)),
      buddies: people.people,
      computer: people.computer,
      tags: {
        ...splitSsiList(col(5)),
        for (final x in splitSsiTabs(col(4))) if (x != usualActivity) x,
        for (final x in splitSsiTabs(col(6))) if (x != usualType) x,
        ?people.center,
      }.toList(),
    ));
  }
  // Las filas sin fecha válida, salvo la cabecera, no se pudieron leer.
  return (dives: out, skipped: (all - rows.length - 1).clamp(0, all));
}

String? _clean(String s) {
  final v = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return v.isEmpty ? null : v;
}

// Trozo (separado por tabuladores) presente en más de la mitad de las filas.
String? _dominant(Iterable<String> cells) {
  final count = <String, int>{};
  var n = 0;
  for (final c in cells) {
    n++;
    for (final x in splitSsiTabs(c).toSet()) {
      count[x] = (count[x] ?? 0) + 1;
    }
  }
  for (final e in count.entries) {
    if (e.value * 2 > n) return e.key;
  }
  return null;
}

// Márgenes para dar una fila del CSV por "ya existente". Ajustados con un
// logbook real: los ordenadores de dos buzos difieren 2-3 m y unos minutos, y
// la hora de MySSI puede ir ~1 h desfasada (zona horaria del ordenador).
const _maxDepthDiff = 3.0; // m
const _maxMinutesDiff = 6.0; // min
const _maxTimeDiff = 90; // min (solo si el CSV trae hora)

typedef _Existing = ({int id, String? time, double? depth, double? minutes});

// Parecido de [d] con [e] (0 = idéntico), o null si no puede ser la misma.
double? _distance(SsiDive d, _Existing e) {
  var score = 0.0;
  if (d.depth != null && e.depth != null) {
    final x = (d.depth! - e.depth!).abs();
    if (x > _maxDepthDiff) return null;
    score += x / _maxDepthDiff;
  }
  if (d.minutes != null && e.minutes != null) {
    final x = (d.minutes! - e.minutes!).abs();
    if (x > _maxMinutesDiff) return null;
    score += x / _maxMinutesDiff;
  }
  final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(e.time ?? '');
  if (d.hasTime && hm != null) {
    final x = (int.parse(hm[1]!) * 60 + int.parse(hm[2]!) -
            (d.date.hour * 60 + d.date.minute))
        .abs();
    if (x > _maxTimeDiff) return null;
    score += x / _maxTimeDiff;
  }
  return score;
}

/// Importa el CSV de SSI en [db]. Ignora las inmersiones que ya estén: mismo
/// día, profundidad ±3 m, duración ±6 min y, si hay hora, ±90 min; entre
/// varias candidatas se empareja con la más parecida.
SsiImportResult importSsiCsv(DivemateDb db, String text) {
  final parsed = parseSsiCsv(text);
  final dives = [...parsed.dives]..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : (a.number ?? 0).compareTo(b.number ?? 0);
    });
  final used = <int>{}; // buceos existentes ya emparejados con una fila
  var added = 0, dup = 0;
  for (final d in dives) {
    final existing = db.divesOnDay(d.date);
    _Existing? match;
    double? best;
    for (final e in existing) {
      final x = used.contains(e.id) ? null : _distance(d, e);
      if (x != null && (best == null || x < best)) (match, best) = (e, x);
    }
    if (match != null) {
      used.add(match.id);
      dup++;
      continue;
    }
    var when = d.date;
    while (db.hasDiveAt(when)) {
      if (d.hasTime) break; // hora real ocupada: es la misma
      when = when.add(const Duration(minutes: 1));
    }
    final ok = db.importExternalDive(
      dateTime: when,
      placeName: d.site,
      country: d.country,
      maxDepth: d.depth,
      durationMin: d.minutes,
      buddies: d.buddies,
      tagNames: d.tags,
      computer: d.computer,
    );
    if (ok) {
      added++;
      // Que otra fila del CSV no la tome por duplicada.
      String p(int v) => v.toString().padLeft(2, '0');
      final hhmm = '${p(when.hour)}:${p(when.minute)}';
      used.addAll(db
          .divesOnDay(when)
          .where((e) => e.time?.startsWith(hhmm) ?? false)
          .map((e) => e.id));
    } else {
      dup++;
    }
  }
  if (added > 0) db.autoRenumber();
  return (added: added, duplicates: dup, skipped: parsed.skipped);
}
