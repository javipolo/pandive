/// Automatic background backup with WorkManager. Periodic task that,
/// even with the app closed, uploads the DB to Drive if it changed (WiFi if requested).
/// Auth is silent; if there is no account or no WiFi, it's a no-op.
library;


import 'package:material_ui/material_ui.dart';
import 'package:workmanager/workmanager.dart';

import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';
import 'sync_controller.dart';
import '../platform.dart';

const _taskName = 'pandive.autoBackup';
const _uniqueName = 'pandive.autoBackup.periodic';
const _syncTask = 'pandive.syncUpload';

/// Entry point of the background isolate (invoked by WorkManager).
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
      return false; // WorkManager will retry per backoff
    }
  });
}

/// WorkManager only exists on Android; on desktop all this is a no-op (the
/// backup on app open still works).
bool get _supported => isAndroid;

/// Registers the dispatcher (once, in the main isolate at startup).
Future<void> initBackupWorker() async {
  if (_supported) await Workmanager().initialize(backupCallbackDispatcher);
}

/// Schedules the periodic task (~12 h; WiFi only if [wifiOnly]). Idempotent:
/// when the option changes it's called again and updates the network constraint.
Future<void> registerAutoBackup({required bool wifiOnly}) async {
  if (!_supported) return;
  await Workmanager().registerPeriodicTask(
    _uniqueName,
    _taskName,
    frequency: const Duration(hours: 12),
    constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// Cancels the periodic task (when automatic backup is turned off).
Future<void> cancelAutoBackup() async {
  if (_supported) await Workmanager().cancelByUniqueName(_uniqueName);
}

/// Fallback sync upload when leaving the app (Android freezes the app in the
/// background): once, as soon as there is network (WiFi if [wifiOnly]). If the
/// foreground upload managed to finish, the task sees there's nothing to do.
Future<void> enqueueSyncUpload({required bool wifiOnly}) async {
  if (!_supported) return;
  await Workmanager().registerOneOffTask(
    _syncTask,
    _syncTask,
    initialDelay: const Duration(seconds: 30),
    constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}
