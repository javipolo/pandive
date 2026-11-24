/// Lista de backups en Drive para restaurar (latest primero). Al elegir uno,
/// confirma, lo descarga, avisa si la DB actual tiene cambios más recientes
/// (sello de última escritura) y sobrescribe la DB activa; luego recarga.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/backup_util.dart';
import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

class RestoreList extends StatefulWidget {
  final DriveBackupService svc;
  final Settings settings;
  final VoidCallback onReloadDb;
  const RestoreList({
    super.key,
    required this.svc,
    required this.settings,
    required this.onReloadDb,
  });

  @override
  State<RestoreList> createState() => _RestoreListState();
}

class _RestoreListState extends State<RestoreList> {
  late final Future<List<BackupEntry>> _future = widget.svc.listBackups();

  Future<void> _restore(BackupEntry e) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (!await confirmDialog(context, t.restoreConfirm(e.name),
        confirmLabel: t.restore)) {
      return;
    }
    if (!mounted) return;
    final file = await withProgress(
        context, t.working, () => widget.svc.downloadBackup(e.id));
    if (!mounted) return;
    if (file == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.backupFailed)));
      return;
    }
    if (!await _confirmIfOlder(file)) {
      await file.delete();
      return;
    }
    final ok = await widget.svc.applyRestore(file, widget.settings);
    if (!mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text(ok ? t.restoreDone : t.backupFailed)));
    if (ok) {
      widget.onReloadDb();
      nav.popUntil((r) => r.isFirst); // volver al inicio con la DB recargada
    }
  }

  /// Failsafe: si la DB actual tiene escrituras más recientes que el backup,
  /// avisa con ambas fechas antes de pisarla. true = seguir.
  Future<bool> _confirmIfOlder(File backup) async {
    final dbPath = widget.settings.dbPath;
    final local = dbPath == null ? null : lastWriteUtcOf(dbPath);
    final remote = lastWriteUtcOf(backup.path);
    if (!restoreWouldLoseData(local, remote) || !mounted) return true;
    final t = AppLocalizations.of(context);
    final fmt = DateFormat.yMd(Localizations.localeOf(context).languageCode).add_Hm();
    return confirmDialog(
      context,
      t.restoreOlderWarning(fmt.format(local!.toLocal()),
          remote == null ? t.unknownDate : fmt.format(remote.toLocal())),
      confirmLabel: t.restoreAnyway,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat(
        'd MMM yyyy, HH:mm', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.restore)),
      body: FutureBuilder<List<BackupEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <BackupEntry>[];
          if (items.isEmpty) {
            return Center(child: Text(t.noResults));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              return ListTile(
                leading: Icon(e.isLatest ? Icons.star : Icons.history),
                title: Text(e.isLatest ? t.latest : e.name),
                subtitle: e.modified == null
                    ? null
                    : Text(fmt.format(e.modified!.toLocal())),
                onTap: () => _restore(e),
              );
            },
          );
        },
      ),
    );
  }
}
