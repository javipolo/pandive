/// Builds the list of dives to offer: new from the device + pending from
/// previous downloads, excluding those already in the DB.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dive_computer/widgets/download_result_list.dart';

({List<DownloadItem> items, int existing}) buildDownloadItems(
    DivemateDb db, String deviceId, List<DownloadedDive> dives) {
  bool inDb(DownloadedDive d) =>
      d.datetime != null && db.hasDiveAt(d.datetime!);
  final deviceNew = [for (final d in dives) if (!inDb(d)) d];
  final seen = {for (final d in deviceNew) d.fingerprint};
  final pending = [
    for (final p in db.listPending(deviceId))
      if (!inDb(p) && seen.add(p.fingerprint)) p,
  ];
  final items = <DownloadItem>[
    for (final d in deviceNew) (dive: d, pending: false),
    for (final p in pending) (dive: p, pending: true),
  ];
  return (items: items, existing: dives.length - deviceNew.length);
}

/// Applies the selection: saves the ticked ones and DISCARDS the unticked ones at once.
/// Advances the fingerprint to the device's most recent (so they aren't downloaded again).
/// Leaving with "back" (without saving) doesn't advance the fingerprint, and the device
/// offers them again on the next download. Returns how many were added.
int applyDownloadSelection({
  required DivemateDb db,
  required String deviceId,
  required List<DownloadItem> items,
  required Set<String> selected,
  required List<DownloadedDive> deviceDives,
  String? computer,
}) {
  var added = 0;
  for (final it in items) {
    final fp = it.dive.fingerprint;
    if (selected.contains(fp) &&
        db.importDownloaded(it.dive, computer: computer)) {
      added++;
    }
    db.removePending(deviceId, fp); // saved or discarded: out of the cache
  }
  if (added > 0) db.autoRenumber();
  if (deviceDives.isNotEmpty) {
    db.setFingerprintFor(deviceId, deviceDives.first.fingerprint);
  }
  return added;
}
