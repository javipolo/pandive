/// Backup automático en segundo plano con WorkManager. Tarea periódica que,
/// aunque la app esté cerrada, sube la DB a Drive si cambió (solo WiFi).
/// La auth es silenciosa; si no hay cuenta o no es WiFi, no-opea.
library;

import 'package:material_ui/material_ui.dart';
import 'package:workmanager/workmanager.dart';

import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';

const _taskName = 'pandive.autoBackup';
const _uniqueName = 'pandive.autoBackup.periodic';

/// Punto de entrada del isolate de background (lo invoca WorkManager).
@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final s = await Settings.load();
      if (s.autoBackup) await DriveBackupService().backupIfChanged(s);
      return true;
    } catch (_) {
      return false; // WorkManager reintentará según backoff
    }
  });
}

/// Registra el dispatcher (una vez, en el isolate principal al arrancar).
Future<void> initBackupWorker() =>
    Workmanager().initialize(backupCallbackDispatcher);

/// Programa la tarea periódica (~12 h, solo WiFi). Idempotente.
Future<void> registerAutoBackup() => Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(hours: 12),
      constraints: Constraints(networkType: NetworkType.unmetered),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );

/// Cancela la tarea periódica (al desactivar el backup automático).
Future<void> cancelAutoBackup() =>
    Workmanager().cancelByUniqueName(_uniqueName);
