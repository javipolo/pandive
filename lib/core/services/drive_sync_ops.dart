part of 'drive_backup.dart';

/// Fichero compartido de la sincronización (en la carpeta de backups; su
/// nombre no casa con los backups con timestamp, así que no se poda). Va
/// comprimido con gzip: una DB de 12 MB queda en <1 MB (datos móviles).
const syncFileName = 'sync-logbook.ddb.gz';
const _presencePrefix = 'presence-';

/// Estado del fichero de sync en Drive.
class RemoteSync {
  final String? id; // null = no existe aún
  final String? md5;
  const RemoteSync(this.id, this.md5);
  bool get exists => id != null;
}

/// Otro dispositivo con Pandive abierto recientemente.
class DevicePresence {
  final String device;
  final DateTime time;
  const DevicePresence(this.device, this.time);
}

/// Operaciones de Drive para [SyncController] (auth silenciosa siempre).
extension DriveSyncOps on DriveBackupService {
  Future<(drive.DriveApi, String)?> _syncApi() async {
    if (!await signInSilently()) return null;
    final api = await _api();
    if (api == null) return null;
    return (api, await _ensureFolder(api));
  }

  /// Estado del fichero de sync, o null sin sesión/red.
  Future<RemoteSync?> remoteSync() async {
    final a = await _syncApi();
    if (a == null) return null;
    final (api, folder) = a;
    final res = await api.files.list(
      q: "'$folder' in parents and name='$syncFileName' and trashed=false",
      $fields: 'files(id,md5Checksum)',
    );
    final f = res.files;
    if (f == null || f.isEmpty) return const RemoteSync(null, null);
    return RemoteSync(f.first.id, f.first.md5Checksum);
  }

  /// Sube [raw] (la DB sin comprimir) como fichero de sync; devuelve su md5.
  Future<String?> uploadSync(List<int> raw, RemoteSync remote) async {
    final a = await _syncApi();
    if (a == null) return null;
    final (api, folder) = a;
    final bytes = gzip.encode(raw);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final f = remote.exists
        ? await api.files.update(drive.File(), remote.id!,
            uploadMedia: media, $fields: 'md5Checksum')
        : await api.files.create(
            drive.File()
              ..name = syncFileName
              ..parents = [folder],
            uploadMedia: media,
            $fields: 'md5Checksum');
    return f.md5Checksum;
  }

  Future<List<int>?> downloadSync(RemoteSync remote) async {
    final a = await _syncApi();
    if (a == null || !remote.exists) return null;
    final media = await a.$1.files.get(remote.id!,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return gzip.decode(bytes);
  }

  /// Guarda la versión descartada en una divergencia como backup con
  /// timestamp (aparece en Restaurar).
  Future<void> uploadDiscarded(List<int> bytes) async {
    final a = await _syncApi();
    if (a == null) return;
    final (api, folder) = a;
    await _upload(api, folder, backupFileName(DateTime.now()), bytes);
    await _prune(api, folder);
  }

  /// Sube el zip de imágenes de documentos si cambiaron desde la última vez.
  Future<void> syncDocumentsUp(Settings s) async {
    final dir = await documentsDir();
    final parts = <String>[
      await for (final e in dir.list())
        if (e is File) '${e.uri.pathSegments.last}:${await e.length()}',
    ]..sort();
    final sig = parts.join('|');
    if (sig == s.syncDocsSig) return;
    final a = await _syncApi();
    if (a == null) return;
    await _backupDocuments(a.$1, a.$2);
    await s.setSyncDocsSig(sig);
  }

  Future<void> syncDocumentsDown() async {
    final a = await _syncApi();
    if (a != null) await _restoreDocuments(a.$1, a.$2);
  }

  /// Marca este dispositivo como activo ahora.
  Future<void> writePresence(String deviceId, String deviceName) async {
    final a = await _syncApi();
    if (a == null) return;
    final body = utf8.encode(jsonEncode({
      'device': deviceName,
      'time': DateTime.now().toUtc().toIso8601String(),
    }));
    await _upload(a.$1, a.$2, '$_presencePrefix$deviceId.json', body,
        replace: true);
  }

  /// Presencia de los demás dispositivos (cualquier antigüedad).
  Future<List<DevicePresence>> otherPresence(String deviceId) async {
    final a = await _syncApi();
    if (a == null) return const [];
    final (api, folder) = a;
    final res = await api.files.list(
      q: "'$folder' in parents and name contains '$_presencePrefix' "
          'and trashed=false',
      $fields: 'files(id,name)',
    );
    final out = <DevicePresence>[];
    for (final f in res.files ?? const <drive.File>[]) {
      if (f.name == '$_presencePrefix$deviceId.json') continue;
      try {
        final media = await api.files.get(f.id!,
            downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final j = jsonDecode(await utf8.decodeStream(media.stream))
            as Map<String, dynamic>;
        final t = DateTime.tryParse(j['time'] as String? ?? '');
        if (t != null) out.add(DevicePresence(j['device'] as String? ?? '?', t));
      } catch (_) {/* presencia corrupta: ignorar */}
    }
    return out;
  }
}
