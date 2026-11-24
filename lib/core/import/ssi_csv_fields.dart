/// Lectura de las celdas del CSV de MySSI: CSV, fechas multi-idioma,
/// duración, profundidad, la celda de compañeros (personas pegadas + centro +
/// ordenador) y las listas de etiquetas. Sin acceso a la DB.
library;

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

// Tramo de espacios con algún tabulador: separa los bloques de una celda
// (MySSI aplana su HTML así).
final _tabRun = RegExp(r' *\t[\t ]*');

/// Trozos de una celda separados por tabuladores ("Buceo\t\tInmersión con
/// descompresión" -> ["Buceo", "Inmersión con descompresión"]).
List<String> splitSsiTabs(String cell) =>
    [for (final x in cell.split(_tabRun)) ?_blank(x)];

/// Especialidades separadas por comas -> etiquetas.
List<String> splitSsiList(String cell) =>
    [for (final x in cell.split(RegExp(r'[,;]'))) ?_blank(x)];

/// Celda "Compañero de buceo / Instructor / Center". MySSI pega los nombres
/// sin separador ("Javi  PoloDaniel Grau Olalla") y añade, tras tabuladores,
/// el centro (precedido de <= 8 tabuladores) y el ordenador (9 o más):
/// "Ana PérezLuis Gil\t\t…  POSIDONIA DIVE  \t\t…\t Puck4".
({List<String> people, String? center, String? computer}) parseSsiPeople(
    String cell) {
  final seps = _tabRun.allMatches(cell).toList();
  final parts = cell.split(_tabRun);
  String? center, computer;
  for (var i = 1; i < parts.length; i++) {
    final v = _blank(parts[i]);
    if (v == null) continue;
    final tabs = '\t'.allMatches(seps[i - 1][0]!).length;
    if (tabs >= 9) {
      computer = v;
    } else {
      center = v;
    }
  }
  return (people: splitGluedNames(parts.first), center: center, computer: computer);
}

/// Separa nombres pegados por el cambio minúscula -> Mayúscula, y también
/// por comas: "Javi  PoloDaniel Grau, Ana" -> [Javi Polo, Daniel Grau, Ana].
/// (Un apellido tipo "McDonald" se partiría: limitación conocida.)
List<String> splitGluedNames(String s) => [
      for (final part in splitSsiList(s))
        for (final n in part.split(RegExp(r'(?<=\p{Ll})(?=\p{Lu})', unicode: true)))
          ?_blank(n),
    ];
