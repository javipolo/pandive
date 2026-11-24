/// Decisión pura de la sincronización entre dispositivos (capa 1, ver
/// docs/sync-plan.md). Nunca fusiona: avanza al lado que cambió o, si
/// cambiaron los dos, declara divergencia para que decida el usuario.
library;

enum SyncAction {
  none, // ya sincronizado
  upload, // solo cambié yo (o no hay fichero en Drive)
  download, // solo cambió el otro (o soy un dispositivo nuevo y vacío)
  diverged, // cambiaron ambos: no tocar nada sin preguntar
}

/// Estado observado en una pasada de sync.
class SyncObservation {
  final String? baseMd5; // md5 en Drive en la última sync (null = nunca)
  final String? baseStamp; // sello local en la última sync
  final String? localStamp; // sello local ahora
  final bool localEmpty; // la DB local no tiene inmersiones
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

  /// Cualquier escritura local cambia el sello (triggers), incluido
  /// restaurar un backup (sello distinto aunque sea más viejo).
  bool get localChanged => localStamp != baseStamp;
  bool get remoteChanged => remoteExists && remoteMd5 != baseMd5;
}

SyncAction decideSync(SyncObservation o) {
  if (!o.remoteExists) return SyncAction.upload; // primer dispositivo
  if (o.baseMd5 == null) {
    // Dispositivo nuevo en la sync: si está vacío, adopta lo de Drive; si no,
    // hay dos historias distintas y decide el usuario.
    return o.localEmpty ? SyncAction.download : SyncAction.diverged;
  }
  final mine = o.localChanged, theirs = o.remoteChanged;
  if (mine && theirs) return SyncAction.diverged;
  if (mine) return SyncAction.upload;
  if (theirs) return SyncAction.download;
  return SyncAction.none;
}
