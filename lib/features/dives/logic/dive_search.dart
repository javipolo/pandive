/// Coincidencia de búsqueda de inmersiones, insensible a acentos y mayúsculas.
/// Busca en sitio, país, notas, compañeros (texto) y tipo; o por nº exacto.
library;

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';

bool diveMatches(Dive d, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  for (final s in [d.place, d.country, d.comments, d.buddy, d.diveType]) {
    if (s != null && foldContains(s, q)) return true;
  }
  return d.number?.toString() == q;
}

List<Dive> filterDives(List<Dive> dives, String query) =>
    query.trim().isEmpty
        ? dives
        : [for (final d in dives) if (diveMatches(d, query)) d];
