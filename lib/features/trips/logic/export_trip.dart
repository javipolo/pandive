/// Exports a trip as .ddb: its dives (data, site with coordinates,
/// buddies, cylinders, tags, computer and, optionally, the profile), the trip
/// itself and the trip buddies. Shares it named
/// "Year-Trip name-PanDive.ddb".
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Generates the .ddb of one or several trips (temp file) to share
/// or save with shareOrSaveFile. null if there are no trips.
Future<File?> buildTripsDdb(DivemateDb source, List<Trip> trips,
    {bool withProfiles = false}) async {
  if (trips.isEmpty) return null;
  if (trips.length == 1) {
    return buildTripDdb(source, trips.first, withProfiles: withProfiles);
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${tripsFileBase(trips)}.ddb');
  if (f.existsSync()) f.deleteSync();
  final out = DivemateDb.createEmpty(f.path);
  try {
    for (final trip in trips) {
      await writeTripDdb(source, trip, out, source.listDivesByTrip(trip.id),
          withProfiles: withProfiles);
    }
  } finally {
    out.close();
  }
  return f;
}

/// Base name for several trips: names joined with "_", or "N-trips" if long.
String tripsFileBase(List<Trip> trips) {
  if (trips.length == 1) return tripFileBase(trips.first, const []);
  final names = trips
      .map((t) => t.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim())
      .where((s) => s.isNotEmpty)
      .join('_');
  final base = names.length <= 50 ? names : '${trips.length}-trips';
  return '$base-PanDive';
}

/// Base file name: "Year-Trip name-PanDive".
String tripFileBase(Trip trip, List<Dive> dives) {
  final year = (trip.lastDate ?? trip.firstDate ?? _firstDate(dives))?.year;
  final safe = trip.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  return [
    if (year != null) '$year',
    if (safe.isNotEmpty) safe,
    'PanDive',
  ].join('-');
}

/// Builds the trip's .ddb in a temp file and returns it (without
/// compartir).
Future<File> buildTripDdb(DivemateDb source, Trip trip,
    {bool withProfiles = false}) async {
  final dives = source.listDivesByTrip(trip.id);
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${tripFileBase(trip, dives)}.ddb');
  if (f.existsSync()) f.deleteSync();
  final out = DivemateDb.createEmpty(f.path);
  try {
    await writeTripDdb(source, trip, out, dives, withProfiles: withProfiles);
  } finally {
    out.close();
  }
  return f;
}

/// Populates [out] with the trip, its dives and buddies (with
/// [withProfiles], also each dive's profile). Yields frames every few
/// dives so as not to freeze the UI. Testable (no IO).
Future<void> writeTripDdb(
  DivemateDb source,
  Trip trip,
  DivemateDb out,
  List<Dive> dives, {
  bool withProfiles = false,
}) async {
  final outTrip = out.createTrip(trip.name);
  out.setTripBuddies(outTrip, [
    for (final b in source.tripBuddies(trip.id)) out.findOrCreateBuddy(b.name),
  ]);

  var i = 0;
  for (final d in dives) {
    if (i++ % 10 == 9) await Future<void>.delayed(Duration.zero);
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
    out.copyDiveDetailsFrom(newId, source, d.id, withProfile: withProfiles);
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
