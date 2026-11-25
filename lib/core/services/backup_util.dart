/// Pure (testable) utilities for Drive backup names/pruning.
library;

import 'dart:io';

/// Backups are uploaded gzip-compressed (12 MB -> <1 MB). Old
/// uncompressed ones (.ddb) are still listed and restored.
const latestBackupName = 'latest.ddb.gz';
const legacyLatestBackupName = 'latest.ddb';
const documentsBackupName = 'documents-latest.zip';

String _p2(int v) => v.toString().padLeft(2, '0');

/// Name with local timestamp: pandive-YYYYMMDD-HHMMSS.ddb.gz
String backupFileName(DateTime t) =>
    'pandive-${t.year}${_p2(t.month)}${_p2(t.day)}-'
    '${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}.ddb.gz';

/// Decompresses if gzip (header 1f 8b); an old .ddb passes through as is.
List<int> maybeGunzip(List<int> bytes) =>
    bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b
        ? gzip.decode(bytes)
        : bytes;

/// Would restoring a backup with stamp [backup] overwrite data newer than the
/// local one ([local])? Without a local stamp we can't tell: no warning. Backup without a stamp
/// (older than the feature) and local with a stamp: almost certainly older, warn.
bool restoreWouldLoseData(DateTime? local, DateTime? backup) =>
    local != null && (backup == null || local.isAfter(backup));

/// Is it a timestamped copy (not the "latest")?
bool isTimestampedBackup(String name) =>
    name.startsWith('pandive-') &&
    (name.endsWith('.ddb') || name.endsWith('.ddb.gz'));

/// Given a list of timestamped copies (id + date), returns the ids to
/// delete to keep only the [keep] most recent.
List<String> idsToPrune(List<(String id, DateTime when)> items,
    {int keep = 10}) {
  final sorted = [...items]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (var i = keep; i < sorted.length; i++) sorted[i].$1];
}
