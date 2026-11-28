/// Web: the logbook comes from Google Drive. Signs in, downloads the synced
/// logbook (the one the phone uploads) into memory and makes it the sync
/// base, so edits go back to Drive. Logbooks opened from a file start with
/// sync off, so a stale base from an earlier visit can't overwrite Drive.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/db/open/sqlite_open.dart';
import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Path of the in-memory logbook on web.
const webDbPath = '/logbook.ddb';

/// Signs in (popup: call it from the button) and downloads the synced
/// logbook. Returns its path, or null if Drive has no synced logbook yet.
Future<String?> openFromDrive(BuildContext context, Settings s) async {
  final t = AppLocalizations.of(context);
  final svc = DriveBackupService();
  if (!svc.connected) await svc.signIn();
  if (!context.mounted) return null;
  return withProgress(context, t.driveDownloading, () async {
    final remote = await svc.remoteSync();
    if (remote == null) throw StateError(t.driveUnreachable);
    if (!remote.exists) return null;
    final bytes = await svc.downloadSync(remote);
    if (bytes == null) throw StateError(t.driveUnreachable);
    await writeDbFile(webDbPath, bytes);
    // Base stamp = that of the opened DB (opening may fill in columns).
    final db = DivemateDb.open(webDbPath);
    final stamp = db.lastWriteRaw;
    db.close();
    await s.setSyncBase(remote.md5, stamp);
    await s.setSyncEnabled(true);
    return webDbPath;
  });
}

/// A logbook not from Drive: sync off and no base (turning sync on later
/// asks what to keep instead of overwriting either side).
Future<void> detachWebSync(Settings s) async {
  await s.setSyncEnabled(false);
  await s.setSyncBase(null, null);
}
