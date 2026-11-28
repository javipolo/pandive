part of 'drive_backup.dart';

/// Shared sync file (in the backups folder; its
/// name doesn't match the timestamped backups, so it isn't pruned). It's
/// gzip-compressed: a 12 MB DB becomes <1 MB (mobile data).
const syncFileName = 'sync-logbook.ddb.gz';
const _presencePrefix = 'presence-';

/// State of the sync file on Drive.
class RemoteSync {
  final String? id; // null = doesn't exist yet
  final String? md5;
  const RemoteSync(this.id, this.md5);
  bool get exists => id != null;
}

/// Another device with Pandive open recently.
class DevicePresence {
  final String device;
  final DateTime time;
  const DevicePresence(this.device, this.time);
}

/// Drive operations for [SyncController] (always silent auth).
extension DriveSyncOps on DriveBackupService {
  Future<(drive.DriveApi, String)?> _syncApi() async {
    if (!await signInSilently()) return null;
    final api = await _api();
    if (api == null) return null;
    return (api, await _ensureFolder(api));
  }

  /// State of the sync file, or null without session/network.
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

  /// Uploads [raw] (the uncompressed DB) as the sync file; returns its md5.
  Future<String?> uploadSync(List<int> raw, RemoteSync remote) async {
    final a = await _syncApi();
    if (a == null) return null;
    final (api, folder) = a;
    final bytes = GZipEncoder().encodeBytes(raw);
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
    return GZipDecoder().decodeBytes(bytes);
  }

  /// Saves the version discarded in a divergence as a timestamped
  /// backup (shows up in Restore).
  Future<void> uploadDiscarded(List<int> bytes) async {
    final a = await _syncApi();
    if (a == null) return;
    final (api, folder) = a;
    await _upload(api, folder, backupFileName(DateTime.now()), GZipEncoder().encodeBytes(bytes));
    await _prune(api, folder);
  }

  /// Uploads the document images zip if they changed since last time.
  Future<void> syncDocumentsUp(Settings s) async {
    if (isWeb) return; // no documents on web (no files on disk)
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
    if (isWeb) return;
    final a = await _syncApi();
    if (a != null) await _restoreDocuments(a.$1, a.$2);
  }

  /// Marks this device as active now.
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

  /// Presence of the other devices (any age).
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
