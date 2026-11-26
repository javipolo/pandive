/// Copies one dive from a .ddb into another .ddb being exported: data, site
/// with coordinates, port, buddies, computer, cylinders, tags and,
/// optionally, the profile. Shared by the trip export and the dive-selection export.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Writes [d] (from [source]) into [out]. Returns the new ID, or null if the
/// dive has no date (not exportable).
int? copyDiveToDdb(DivemateDb source, DivemateDb out, Dive d,
    {bool withProfile = false}) {
  final dt = d.date;
  if (dt == null) return null;
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
  out.copyDiveDetailsFrom(newId, source, d.id, withProfile: withProfile);
  out.setDivePort(newId, copyPortToDdb(out, source.portForDive(d.id)));
  return newId;
}

/// The same port (by name, with its position) in [out]; null for null.
int? copyPortToDdb(DivemateDb out, Port? p) =>
    p == null ? null : out.findOrCreatePort(p.name, lat: p.lat, lon: p.lon);
