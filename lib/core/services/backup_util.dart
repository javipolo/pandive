/// Pure (testable) utilities for Drive backup names/pruning.
library;

import 'package:archive/archive.dart';

/// Backups are uploaded gzip-compressed (12 MB -> <1 MB), all named
/// `PanDive-…`. Old names (`latest.ddb[.gz]`, `pandive-…`, uncompressed .ddb)
/// are still listed, restored and pruned.
const backupPrefix = 'PanDive-';
const latestBackupName = '${backupPrefix}latest.ddb.gz';
const legacyLatestBackupNames = {'latest.ddb.gz', 'latest.ddb'};
const documentsBackupName = '${backupPrefix}documents-latest.zip';
const legacyDocumentsBackupName = 'documents-latest.zip';

String _p2(int v) => v.toString().padLeft(2, '0');

/// Name with local timestamp: PanDive-YYYYMMDD-HHMMSS.ddb.gz
String backupFileName(DateTime t) =>
    '$backupPrefix${t.year}${_p2(t.month)}${_p2(t.day)}-'
    '${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}.ddb.gz';

/// Decompresses if gzip (header 1f 8b); an old .ddb passes through as is.
List<int> maybeGunzip(List<int> bytes) =>
    bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b
        ? GZipDecoder().decodeBytes(bytes)
        : bytes;

/// Would restoring a backup with stamp [backup] overwrite data newer than the
/// local one ([local])? Without a local stamp we can't tell: no warning. Backup without a stamp
/// (older than the feature) and local with a stamp: almost certainly older, warn.
bool restoreWouldLoseData(DateTime? local, DateTime? backup) =>
    local != null && (backup == null || local.isAfter(backup));

final _timestamped = RegExp(r'^(PanDive|pandive)-\d{8}-\d{6}\.ddb(\.gz)?$');

/// Is it a timestamped copy (not the "latest")? Also the old `pandive-…` ones.
bool isTimestampedBackup(String name) => _timestamped.hasMatch(name);

/// Copies that count towards the [idsToPrune] limit: the timestamped ones and
/// the old "latest" files, which are no longer updated and so age out.
bool isPrunableBackup(String name) =>
    isTimestampedBackup(name) || legacyLatestBackupNames.contains(name);

/// Given a list of timestamped copies (id + date), returns the ids to
/// delete to keep only the [keep] most recent.
List<String> idsToPrune(List<(String id, DateTime when)> items,
    {int keep = 10}) {
  final sorted = [...items]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (var i = keep; i < sorted.length; i++) sorted[i].$1];
}
