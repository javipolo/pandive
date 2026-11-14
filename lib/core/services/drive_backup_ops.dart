part of 'drive_backup.dart';

/// Operaciones de backup/restauración sobre [DriveBackupService].
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
        if (isTimestampedBackup(f.name ?? ''))
          (f.id!, f.modifiedTime ?? DateTime(0)),
    ];
    for (final id in idsToPrune(items)) {
      await api.files.delete(id);
    }
  }

  /// Sube la DB como latest + copia con timestamp y poda a 10. Guarda estado.
  Future<bool> backupNow(Settings s, {bool interactive = true}) async {
    final path = s.dbPath;
    if (path == null) return false;
    final api = await _api(interactive: interactive);
    if (api == null) return false;
    final bytes = await File(path).readAsBytes();
    final folder = await _ensureFolder(api);
    await _upload(api, folder, latestBackupName, bytes, replace: true);
    await _upload(api, folder, backupFileName(DateTime.now()), bytes);
    await _prune(api, folder);
    await s.setBackupState(
        sha256.convert(bytes).toString(), DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  /// Backup automático diario: solo si hay cuenta, pasaron >24 h y la DB cambió.
  Future<void> backupIfNeeded(Settings s) async {
    if (!s.autoBackup) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - s.backupLastTime < const Duration(hours: 24).inMilliseconds) {
      return;
    }
    if (!await signInSilently()) return;
    final hash = await dbHash(s.dbPath);
    if (hash == null) return;
    if (hash == s.backupLastHash) {
      await s.setBackupState(hash, now); // sin cambios: solo refresca la fecha
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
      if (latest || isTimestampedBackup(name)) {
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

  /// Descarga el backup [fileId] y sobrescribe la DB activa.
  Future<bool> restore(String fileId, Settings s) async {
    final path = s.dbPath;
    if (path == null) return false;
    final api = await _api(interactive: true);
    if (api == null) return false;
    final media = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return true;
  }
}
