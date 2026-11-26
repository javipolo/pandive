part of 'drive_backup.dart';

/// Backup/restore operations on [DriveBackupService].
extension DriveBackupOps on DriveBackupService {
  Future<drive.File?> _findInFolder(
      drive.DriveApi api, String folderId, String name) async {
    final res = await api.files.list(
      q: "'$folderId' in parents and name='$name' and trashed=false",
      $fields: 'files(id,name)',
    );
    final f = res.files;
    return (f != null && f.isNotEmpty) ? f.first : null;
  }

  Future<void> _upload(drive.DriveApi api, String folderId, String name,
      List<int> bytes,
      {bool replace = false}) async {
    final media = drive.Media(Stream.value(bytes), bytes.length);
    if (replace) {
      final existing = await _findInFolder(api, folderId, name);
      if (existing != null) {
        await api.files.update(drive.File(), existing.id!, uploadMedia: media);
        return;
      }
    }
    await api.files.create(
      drive.File()
        ..name = name
        ..parents = [folderId],
      uploadMedia: media,
    );
  }

  Future<void> _prune(drive.DriveApi api, String folderId) async {
    final res = await api.files.list(
      q: "'$folderId' in parents and trashed=false",
      $fields: 'files(id,name,modifiedTime)',
    );
    final items = <(String, DateTime)>[
      for (final f in res.files ?? const <drive.File>[])
        if (isPrunableBackup(f.name ?? ''))
          (f.id!, f.modifiedTime ?? DateTime(0)),
    ];
    for (final id in idsToPrune(items)) {
      await api.files.delete(id);
    }
  }

  /// Uploads the DB as latest + timestamped copy and prunes to 10. Stores state.
  /// Also uploads the document images as a zip ("latest" only).
  Future<bool> backupNow(Settings s, {bool interactive = true}) async {
    final path = s.dbPath;
    if (path == null) return false;
    final api = await _api(interactive: interactive);
    if (api == null) return false;
    final bytes = await File(path).readAsBytes();
    final gz = gzip.encode(bytes);
    final folder = await _ensureFolder(api);
    await _upload(api, folder, latestBackupName, gz, replace: true);
    await _upload(api, folder, backupFileName(DateTime.now()), gz);
    await _prune(api, folder);
    await _backupDocuments(api, folder);
    await s.setBackupState(
        sha256.convert(bytes).toString(), DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  /// Compresses the images in `documents/` and uploads them as [documentsBackupName]
  /// (replacing). If there are no images, does nothing.
  Future<void> _backupDocuments(drive.DriveApi api, String folder) async {
    final dir = await documentsDir();
    final archive = Archive();
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final data = await e.readAsBytes();
      archive.addFile(
          ArchiveFile(e.uri.pathSegments.last, data.length, data));
    }
    if (archive.isEmpty) return;
    final zip = ZipEncoder().encode(archive);
    await _upload(api, folder, documentsBackupName, zip, replace: true);
    // The old-named zip would go stale: drop it once the new one is up.
    final legacy = await _findInFolder(api, folder, legacyDocumentsBackupName);
    if (legacy != null) await api.files.delete(legacy.id!);
  }

  /// Downloads and unpacks [documentsBackupName] (or the old-named zip) into
  /// `documents/`, if it exists.
  Future<void> _restoreDocuments(drive.DriveApi api, String folder) async {
    final existing = await _findInFolder(api, folder, documentsBackupName) ??
        await _findInFolder(api, folder, legacyDocumentsBackupName);
    if (existing == null) return;
    final media = await api.files.get(existing.id!,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    final dir = await documentsDir();
    for (final file in ZipDecoder().decodeBytes(bytes)) {
      if (!file.isFile) continue;
      await File('${dir.path}/${file.name}')
          .writeAsBytes(file.content as List<int>, flush: true);
    }
  }

  /// Like [backupNow] but only if the DB changed since the last backup. No time
  /// gate (WorkManager controls the cadence). Silent auth. Returns
  /// true if it uploaded something.
  Future<bool> backupIfChanged(Settings s) async {
    if (!await signInSilently()) return false;
    final hash = await dbHash(s.dbPath);
    if (hash == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (hash == s.backupLastHash) {
      await s.setBackupState(hash, now); // no changes: only refreshes the date
      return false;
    }
    return backupNow(s, interactive: false);
  }

  /// Daily automatic backup: only if there's an account, >24 h passed and the DB changed.
  Future<void> backupIfNeeded(Settings s) async {
    if (!s.autoBackup) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - s.backupLastTime < const Duration(hours: 24).inMilliseconds) {
      return;
    }
    if (s.backupWifiOnly && !await onUnmeteredNetwork()) return;
    if (!await signInSilently()) return;
    final hash = await dbHash(s.dbPath);
    if (hash == null) return;
    if (hash == s.backupLastHash) {
      await s.setBackupState(hash, now); // no changes: only refreshes the date
      return;
    }
    await backupNow(s, interactive: false);
  }

  Future<List<BackupEntry>> listBackups() async {
    final api = await _api(interactive: true);
    if (api == null) return const [];
    final folder = await _ensureFolder(api);
    final res = await api.files.list(
      q: "'$folder' in parents and trashed=false",
      $fields: 'files(id,name,modifiedTime)',
      orderBy: 'modifiedTime desc',
    );
    final out = <BackupEntry>[];
    for (final f in res.files ?? const <drive.File>[]) {
      final name = f.name ?? '';
      final latest = name == latestBackupName;
      // old latest.ddb[.gz]: listed as one more copy.
      if (latest || isPrunableBackup(name)) {
        out.add(BackupEntry(f.id!, name, f.modifiedTime, latest));
      }
    }
    out.sort((a, b) => a.isLatest
        ? -1
        : b.isLatest
            ? 1
            : (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)));
    return out;
  }

  /// Downloads backup [fileId] to a temp file, to review it (last-write
  /// stamp) before applying it with [applyRestore]. Null on failure.
  Future<File?> downloadBackup(String fileId) async {
    final api = await _api(interactive: true);
    if (api == null) return null;
    final media = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    final f = File('${Directory.systemTemp.path}/pandive-restore-'
        '${DateTime.now().millisecondsSinceEpoch}.ddb');
    await f.writeAsBytes(maybeGunzip(bytes), flush: true);
    return f;
  }

  /// Replaces the active DB with [file] (from [downloadBackup]) and restores the
  /// documents. Deletes the temp file.
  Future<bool> applyRestore(File file, Settings s) async {
    final path = s.dbPath;
    final api = await _api(interactive: true);
    if (path == null || api == null) return false;
    await file.copy(path);
    await file.delete();
    await _restoreDocuments(api, await _ensureFolder(api));
    return true;
  }
}
