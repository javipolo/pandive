/// Pure cross-device sync decision (layer 1, see
/// docs/sync-plan.md). Never merges: moves forward to the side that changed or, if
/// both changed, declares divergence so the user decides.
library;

enum SyncAction {
  none, // already in sync
  upload, // only I changed (or there's no file on Drive)
  download, // only the other changed (or I'm a new, empty device)
  diverged, // both changed: touch nothing without asking
}

/// State observed in a sync pass.
class SyncObservation {
  final String? baseMd5; // md5 on Drive at the last sync (null = never)
  final String? baseStamp; // local stamp at the last sync
  final String? localStamp; // local stamp now
  final bool localEmpty; // the local DB has no dives
  final bool remoteExists;
  final String? remoteMd5;

  const SyncObservation({
    required this.baseMd5,
    required this.baseStamp,
    required this.localStamp,
    required this.localEmpty,
    required this.remoteExists,
    required this.remoteMd5,
  });

  /// Any local write changes the stamp (triggers), including
  /// restoring a backup (different stamp even if older).
  bool get localChanged => localStamp != baseStamp;
  bool get remoteChanged => remoteExists && remoteMd5 != baseMd5;
}

SyncAction decideSync(SyncObservation o) {
  if (!o.remoteExists) return SyncAction.upload; // first device
  if (o.baseMd5 == null) {
    // New device in the sync: if empty, adopts Drive's; otherwise
    // there are two different histories and the user decides.
    return o.localEmpty ? SyncAction.download : SyncAction.diverged;
  }
  final mine = o.localChanged, theirs = o.remoteChanged;
  if (mine && theirs) return SyncAction.diverged;
  if (mine) return SyncAction.upload;
  if (theirs) return SyncAction.download;
  return SyncAction.none;
}
