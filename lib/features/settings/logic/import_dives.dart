/// Copia inmersiones de otro .ddb al logbook propio (p.ej. pasar el viaje a un
/// compañero sin ordenador). Reutiliza `importExternalDive` (dedupe por
/// fecha/hora, copia perfil, sitio con coords, compañeros, tags y botellas).
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Importa en [target] las inmersiones de [source]. Devuelve cuántas añadió
/// (las ya presentes por fecha/hora se omiten).
int importDivesFromDb(DivemateDb target, DivemateDb source) {
  var n = 0;
  for (final d in source.listDives()) {
    final dt = d.date;
    if (dt == null) continue;
    final site = d.placeId != null ? source.getSite(d.placeId!) : null;
    final ok = target.importExternalDive(
      dateTime: dt,
      placeName: site?.name ?? d.place,
      country: site?.country ?? d.country,
      lat: site?.lat,
      lon: site?.lon,
      comments: d.comments,
      buddies: [for (final b in source.diveBuddies(d.id)) b.name],
      tagNames: [for (final tg in source.tagsForDive(d.id)) tg.name],
      maxDepth: d.maxDepth,
      avgDepth: d.avgDepth,
      durationMin: d.durationMin,
      waterTemp: d.waterTemp,
      airTemp: d.airTemp,
      computer: d.computer,
      o2: d.o2,
      samples: _samples(source, d.id),
      cylinders: source.cylinders(d.id),
    );
    if (ok) n++;
  }
  return n;
}

List<DiveSample> _samples(DivemateDb source, int diveId) {
  final p = source.diveProfile(diveId);
  if (p == null) return const [];
  double? at(List<double?> xs, int i) => i < xs.length ? xs[i] : null;
  return [
    for (var i = 0; i < p.depths.length; i++)
      DiveSample(
        (p.timesMinutes[i] * 60000).round(),
        p.depths[i],
        at(p.temps, i),
      ),
  ];
}
