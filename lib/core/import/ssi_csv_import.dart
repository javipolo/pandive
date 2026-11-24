/// Importa el CSV del logbook que exporta la web de SSI (MySSI). La cabecera
/// va en el idioma del usuario, así que las columnas se leen por posición:
///   0 nº · 1 lugar · 2 país · 3 fecha[/hora] · 4 actividad · 5 especialidad ·
///   6 tipo · 7 duración · 8 profundidad · 9 compañeros/instructor/centro
/// La hora solo viene si el buceador la rellenó en MySSI. Los duplicados se
/// detectan por día + profundidad + duración (+ hora ±60 min si la hay); las
/// que no traen hora se colocan a las 12:00 (+1 min por cada una que ya
/// ocupe esa hora), en el orden del nº de SSI.
library;

import 'package:pandive/core/db/divemate_db.dart';

/// Una fila del CSV de SSI ya interpretada.
class SsiDive {
  final int? number;
  final DateTime date; // con hora solo si [hasTime]
  final bool hasTime;
  final String? site;
  final String? country;
  final String? specialty;
  final double? minutes;
  final double? depth; // metros
  final List<String> buddies;
  const SsiDive({
    required this.date,
    this.hasTime = false,
    this.number,
    this.site,
    this.country,
    this.specialty,
    this.minutes,
    this.depth,
    this.buddies = const [],
  });
}

/// Resultado de una importación: añadidas, ya existentes y filas ilegibles.
typedef SsiImportResult = ({int added, int duplicates, int skipped});

/// Parte un CSV (comillas dobles, "" escapadas, saltos de línea dentro de
/// comillas). Detecta el separador (`,` o `;`) en la primera línea.
List<List<String>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final sep = ';'.allMatches(firstLine).length >
          ','.allMatches(firstLine).length
      ? ';'
      : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString());
  if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
  return rows;
}

// Abreviaturas de mes (3 primeras letras, sin acentos) en los idiomas
// habituales de MySSI.
const _months = <String, int>{
  'jan': 1, 'janv': 1, 'jän': 1, 'ene': 1, 'gen': 1, 'urt': 1,
  'feb': 2, 'fev': 2, 'fév': 2, 'ots': 2,
  'mar': 3, 'mär': 3, 'mrt': 3,
  'apr': 4, 'abr': 4, 'avr': 4, 'api': 4,
  'may': 5, 'mai': 5, 'mag': 5, 'mei': 5,
  'jun': 6, 'juny': 6, 'giu': 6, 'eka': 6,
  'jul': 7, 'lug': 7, 'uzt': 7,
  'aug': 8, 'ago': 8, 'aoû': 8, 'aou': 8, 'abu': 8,
  'sep': 9, 'set': 9, 'ira': 9,
  'oct': 10, 'okt': 10, 'out': 10, 'ott': 10, 'urr': 10,
  'nov': 11, 'aza': 11,
  'dec': 12, 'dic': 12, 'déc': 12, 'dez': 12, 'des': 12, 'abe': 12,
};

int? _month(String word) {
  final w = word.toLowerCase().replaceAll('.', '');
  if (w.isEmpty) return null;
  // Francés: "juin" / "juil." comparten "jui".
  if (w.startsWith('juin')) return 6;
  if (w.startsWith('juil')) return 7;
  for (final len in [4, 3]) {
    if (w.length >= len) {
      final m = _months[w.substring(0, len)];
      if (m != null) return m;
    }
  }
  return null;
}

/// Fecha de SSI: "15. Apr 2026", "15 abr. 2026", "15.04.2026",
/// "2026-04-15", "15/04/2026", con hora opcional "10:30" detrás.
({DateTime date, bool hasTime})? parseSsiDate(String raw) {
  final s = raw.trim();
  final tm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
  final hour = tm != null ? int.parse(tm.group(1)!) : 12;
  final min = tm != null ? int.parse(tm.group(2)!) : 0;
  final d = tm != null ? s.replaceRange(tm.start, tm.end, ' ') : s;
  DateTime? out;
  var m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(d);
  if (m != null) {
    out = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!),
        hour, min);
  }
  m ??= RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{4})').firstMatch(d);
  if (out == null && m != null) {
    out = DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!),
        hour, min);
  }
  if (out == null) {
    m = RegExp(r'(\d{1,2})\.?\s+([^\d\s]+)\s+(\d{4})').firstMatch(d) ??
        RegExp(r'([^\d\s,]+)\s+(\d{1,2}),?\s+(\d{4})').firstMatch(d);
    if (m == null) return null;
    final dayFirst = int.tryParse(m[1]!) != null;
    final month = _month(dayFirst ? m[2]! : m[1]!);
    final day = int.parse(dayFirst ? m[1]! : m[2]!);
    if (month == null) return null;
    out = DateTime(int.parse(m[3]!), month, day, hour, min);
  }
  return (date: out, hasTime: tm != null);
}

/// "56 min", "1 h 5 min", "1:05" -> minutos.
double? parseSsiMinutes(String raw) {
  final s = raw.toLowerCase();
  final hm = RegExp(r'(\d+):(\d{2})').firstMatch(s);
  if (hm != null) return int.parse(hm[1]!) * 60.0 + int.parse(hm[2]!);
  final h = RegExp(r'(\d+)\s*h').firstMatch(s);
  final mm = RegExp(r'(\d+)\s*m').firstMatch(s);
  if (h == null && mm == null) {
    return double.tryParse(s.trim().replaceAll(',', '.'));
  }
  return (h != null ? int.parse(h[1]!) * 60.0 : 0.0) +
      (mm != null ? int.parse(mm[1]!) : 0);
}

/// "21 m (69 ft)", "69 ft (21 m)", "21,5 m" -> metros.
double? parseSsiDepth(String raw) {
  final s = raw.toLowerCase().replaceAll(',', '.');
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*m\b').firstMatch(s);
  if (m != null) return double.parse(m[1]!);
  final ft = RegExp(r'(\d+(?:\.\d+)?)\s*ft').firstMatch(s);
  if (ft != null) return double.parse(ft[1]!) * 0.3048;
  return double.tryParse(s.trim());
}

String? _blank(String? s) {
  final v = s?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return v == null || v.isEmpty ? null : v;
}

/// Interpreta el CSV. Devuelve las inmersiones legibles y cuántas filas de
/// datos no se pudieron leer (sin fecha válida). La cabecera se reconoce por
/// no tener fecha y se ignora.
({List<SsiDive> dives, int skipped}) parseSsiCsv(String text) {
  final rows = parseCsv(text);
  final out = <SsiDive>[];
  var skipped = 0;
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    String col(int n) => n < r.length ? r[n] : '';
    final d = parseSsiDate(col(3));
    if (d == null) {
      if (i > 0) skipped++; // la primera es la cabecera
      continue;
    }
    out.add(SsiDive(
      number: int.tryParse(col(0).trim()),
      date: d.date,
      hasTime: d.hasTime,
      site: _blank(col(1)),
      country: _blank(col(2)),
      specialty: _blank(col(5)),
      minutes: parseSsiMinutes(col(7)),
      depth: parseSsiDepth(col(8)),
      buddies: col(9)
          .split(RegExp(r'[,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    ));
  }
  return (dives: out, skipped: skipped);
}

// ¿Es [d] la misma inmersión que una ya existente ese día?
bool _matches(SsiDive d, ({int id, String? time, double? depth, double? minutes}) e) {
  // Con hora (MySSI la guarda si se rellenó): además, ±60 min, por si se
  // apuntó a mano y aproximada.
  if (d.hasTime && e.time != null) {
    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(e.time!);
    if (hm != null) {
      final mins = int.parse(hm[1]!) * 60 + int.parse(hm[2]!);
      if ((mins - (d.date.hour * 60 + d.date.minute)).abs() > 60) return false;
    }
  }
  if (d.depth != null && e.depth != null && (d.depth! - e.depth!).abs() > 2) {
    return false;
  }
  if (d.minutes != null && e.minutes != null &&
      (d.minutes! - e.minutes!).abs() > 5) {
    return false;
  }
  return true;
}

/// Importa el CSV de SSI en [db]. Ignora las inmersiones que ya estén (mismo
/// día con profundidad ±2 m, duración ±5 min y, si hay hora, ±60 min). La especialidad (p.ej.
/// "Inmersión desde embarcación") se guarda como etiqueta.
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
    final match = existing
        .where((e) => !used.contains(e.id) && _matches(d, e))
        .firstOrNull;
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
      tagNames: [?d.specialty],
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
