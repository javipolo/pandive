/// Exporta un viaje como .ddb: sus inmersiones (datos básicos + sitio con
/// coordenadas + compañeros), el viaje en sí y los compañeros del viaje. Lo
/// comparte con nombre "Año-Nombre del viaje-PanDive.ddb".
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

Future<void> exportTripDdb(DivemateDb source, Trip trip) async {
  final f = await buildTripDdb(source, trip);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
}

/// Nombre base del fichero: "Año-Nombre del viaje-PanDive".
String tripFileBase(Trip trip, List<Dive> dives) {
  final year = (trip.lastDate ?? trip.firstDate ?? _firstDate(dives))?.year;
  final safe = trip.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return [
    if (year != null) '$year',
    if (safe.isNotEmpty) safe,
    'PanDive',
  ].join('-');
}

/// Construye el .ddb del viaje en un fichero temporal y lo devuelve (sin
/// compartir).
Future<File> buildTripDdb(DivemateDb source, Trip trip) async {
  final dives = source.listDivesByTrip(trip.id);
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${tripFileBase(trip, dives)}.ddb');
  if (f.existsSync()) f.deleteSync();
  final out = DivemateDb.createEmpty(f.path);
  try {
    writeTripDdb(source, trip, out, dives);
  } finally {
    out.close();
  }
  return f;
}

/// Pobla [out] con el viaje, sus inmersiones y compañeros. Testeable (sin IO).
void writeTripDdb(
  DivemateDb source,
  Trip trip,
  DivemateDb out,
  List<Dive> dives,
) {
  final outTrip = out.createTrip(trip.name);
  out.setTripBuddies(outTrip, [
    for (final b in source.tripBuddies(trip.id)) out.findOrCreateBuddy(b.name),
  ]);

  for (final d in dives) {
    final dt = d.date;
    if (dt == null) continue;
    final site = d.placeId != null ? source.getSite(d.placeId!) : null;
    final place = site?.name ?? d.place;
    int? placeId;
    if (place != null && place.trim().isNotEmpty) {
      placeId = out.findOrCreateSite(
        place,
        country: site?.country ?? d.country,
        lat: site?.lat,
        lon: site?.lon,
      );
    }
    final names = [for (final b in source.diveBuddies(d.id)) b.name];
    final ids = [for (final n in names) out.findOrCreateBuddy(n)];
    final newId = out.createDive(
      dateTime: dt,
      number: d.number,
      place: place,
      country: site?.country ?? d.country,
      placeId: placeId,
      maxDepth: d.maxDepth,
      avgDepth: d.avgDepth,
      durationMin: d.durationMin,
      waterTemp: d.waterTemp,
      airTemp: d.airTemp,
      weight: d.weight,
      rating: d.rating ?? 0,
      comments: d.comments,
      buddy: names.isEmpty ? null : names.join(', '),
      buddyIds: ids.isEmpty ? null : ids.join(','),
    );
    out.assignDivesToTrip(outTrip, [newId]);
  }
}

DateTime? _firstDate(List<Dive> dives) {
  DateTime? first;
  for (final d in dives) {
    final dt = d.date;
    if (dt != null && (first == null || dt.isBefore(first))) first = dt;
  }
  return first;
}
