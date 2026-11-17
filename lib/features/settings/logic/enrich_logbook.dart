/// Enriquecer buceos cruzándolos con otro .ddb (de un compañero): emparejar por
/// fecha/hora, copiar sitio + notas + buddies y añadir un buddy elegido.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Datos copiables de un buceo del .ddb de origen que empareja con uno propio.
class DiveMatch {
  final String? place;
  final String? country;
  final String? notes;
  final double? lat;
  final double? lon;
  final List<String> buddies;
  const DiveMatch({
    this.place,
    this.country,
    this.notes,
    this.lat,
    this.lon,
    this.buddies = const [],
  });
}

/// Busca en [source] el buceo del mismo día más cercano en hora a [when]
/// (dentro de [tol]); devuelve sus datos copiables, o null si no hay.
DiveMatch? findSourceMatch(DivemateDb source, DateTime when,
    {Duration tol = const Duration(hours: 1)}) {
  Dive? best;
  Duration? bestDiff;
  for (final d in source.listDives()) {
    final dt = d.date;
    if (dt == null) continue;
    if (dt.year != when.year || dt.month != when.month || dt.day != when.day) {
      continue;
    }
    final diff = dt.difference(when).abs();
    if (diff <= tol && (bestDiff == null || diff < bestDiff)) {
      best = d;
      bestDiff = diff;
    }
  }
  if (best == null) return null;
  final site = best.placeId != null ? source.getSite(best.placeId!) : null;
  return DiveMatch(
    place: site?.name ?? best.place,
    country: site?.country ?? best.country,
    lat: site?.lat,
    lon: site?.lon,
    notes: best.comments,
    buddies: source.diveBuddies(best.id).map((b) => b.name).toList(),
  );
}

/// Aplica los [matches] a los buceos [selected] del logbook [db]: copia sitio y
/// notas, y añade los buddies del origen más el [buddy] elegido. Devuelve el
/// número de buceos actualizados.
int applyEnrich(DivemateDb db, Map<int, DiveMatch> matches, Set<int> selected,
    String? buddy) {
  var n = 0;
  for (final id in selected) {
    final m = matches[id];
    if (m == null) continue;
    final fields = <String, Object?>{};
    if (m.place != null && m.place!.trim().isNotEmpty) {
      fields['PlaceID'] = db.findOrCreateSite(m.place!,
          country: m.country, lat: m.lat, lon: m.lon);
      fields['Place'] = m.place;
      fields['Country'] = m.country;
    }
    if (m.notes != null && m.notes!.trim().isNotEmpty) {
      fields['Comments'] = m.notes;
    }
    if (fields.isNotEmpty) db.updateDive(id, fields);
    final names = [if (buddy != null && buddy.trim().isNotEmpty) buddy, ...m.buddies];
    if (names.isNotEmpty) db.addDiveBuddies(id, names);
    n++;
  }
  return n;
}
