/// Backup automático en segundo plano con WorkManager. Tarea periódica que,
/// aunque la app esté cerrada, sube la DB a Drive si cambió (solo WiFi).
/// La auth es silenciosa; si no hay cuenta o no es WiFi, no-opea.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:workmanager/workmanager.dart';

import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';
import 'sync_controller.dart';

const _taskName = 'pandive.autoBackup';
const _uniqueName = 'pandive.autoBackup.periodic';
const _syncTask = 'pandive.syncUpload';

/// Punto de entrada del isolate de background (lo invoca WorkManager).
@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final s = await Settings.load();
      if (task == _syncTask) {
        await syncUploadInBackground(s);
      } else if (s.autoBackup) {
        await DriveBackupService().backupIfChanged(s);
      }
      return true;
    } catch (_) {
      return false; // WorkManager reintentará según backoff
    }
  });
}

/// WorkManager solo existe en Android; en escritorio todo esto es no-op (el
/// backup al abrir la app sigue funcionando).
bool get _supported => Platform.isAndroid;

/// Registra el dispatcher (una vez, en el isolate principal al arrancar).
Future<void> initBackupWorker() async {
  if (_supported) await Workmanager().initialize(backupCallbackDispatcher);
}

/// Programa la tarea periódica (~12 h, solo WiFi). Idempotente.
Future<void> registerAutoBackup() async {
  if (!_supported) return;
  await Workmanager().registerPeriodicTask(
    _uniqueName,
    _taskName,
    frequency: const Duration(hours: 12),
    constraints: Constraints(networkType: NetworkType.unmetered),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// Cancela la tarea periódica (al desactivar el backup automático).
Future<void> cancelAutoBackup() async {
  if (_supported) await Workmanager().cancelByUniqueName(_uniqueName);
}

/// Subida de sync de respaldo al salir de la app (Android congela la app en
/// segundo plano): una vez, en cuanto haya red. Si la subida en primer plano
/// llegó a terminar, la tarea ve que no hay nada que subir.
Future<void> enqueueSyncUpload() async {
  if (!_supported) return;
  await Workmanager().registerOneOffTask(
    _syncTask,
    _syncTask,
    initialDelay: const Duration(seconds: 30),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
