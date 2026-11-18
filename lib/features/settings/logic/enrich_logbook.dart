/// Enriquecer buceos cruzándolos con otro .ddb (de un compañero): emparejar por
/// fecha/hora, copiar sitio + notas + buddies y añadir un buddy elegido.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Datos copiables de un buceo del .ddb de origen que empareja con uno propio.
class DiveMatch {
  final String? place;
  final String? country;
  final double? lat;
  final double? lon;
  const DiveMatch({this.place, this.country, this.lat, this.lon});
}

/// Empareja los buceos de [her] con [source] (cede al bucle de eventos para que
/// la UI siga viva). Devuelve los buceos propios con coincidencia y sus datos.
Future<({List<Dive> dives, Map<int, DiveMatch> matches})> computeMatches(
    DivemateDb her, DivemateDb source,
    {Duration tol = const Duration(hours: 1)}) async {
  // Indexa el origen por día una sola vez (evita re-consultar por cada buceo).
  final byDay = <String, List<Dive>>{};
  for (final d in source.listDives()) {
    final dt = d.date;
    if (dt != null) (byDay['${dt.year}-${dt.month}-${dt.day}'] ??= []).add(d);
  }
  final matches = <int, DiveMatch>{};
  final dives = <Dive>[];
  final all = her.listDives();
  for (var i = 0; i < all.length; i++) {
    final dt = all[i].date;
    if (dt != null) {
      Dive? best;
      Duration? bd;
      for (final s in byDay['${dt.year}-${dt.month}-${dt.day}'] ?? const []) {
        final diff = s.date!.difference(dt).abs();
        if (diff <= tol && (bd == null || diff < bd)) {
          best = s;
          bd = diff;
        }
      }
      if (best != null) {
        matches[all[i].id] = _matchFrom(source, best);
        dives.add(all[i]);
      }
    }
    if (i % 20 == 19) await Future<void>.delayed(Duration.zero);
  }
  return (dives: dives, matches: matches);
}

/// Construye los datos copiables desde un buceo del .ddb de origen.
DiveMatch _matchFrom(DivemateDb source, Dive best) {
  final site = best.placeId != null ? source.getSite(best.placeId!) : null;
  return DiveMatch(
    place: site?.name ?? best.place,
    country: site?.country ?? best.country,
    lat: site?.lat,
    lon: site?.lon,
  );
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
  return best == null ? null : _matchFrom(source, best);
}

/// Aplica los [matches] a los buceos [selected] del logbook [db]: copia SOLO el
/// sitio de buceo y añade el [buddy] elegido. No toca botellas, notas ni nada
/// más del buceo. Devuelve el número de buceos actualizados.
int applyEnrich(DivemateDb db, Map<int, DiveMatch> matches, Set<int> selected,
    String? buddy) {
  var n = 0;
  for (final id in selected) {
    final m = matches[id];
    if (m == null) continue;
    if (m.place != null && m.place!.trim().isNotEmpty) {
      db.updateDive(id, {
        'PlaceID': db.findOrCreateSite(m.place!,
            country: m.country, lat: m.lat, lon: m.lon),
        'Place': m.place,
        'Country': m.country,
      });
    }
    if (buddy != null && buddy.trim().isNotEmpty) {
      db.addDiveBuddies(id, [buddy]);
    }
    n++;
  }
  return n;
}
