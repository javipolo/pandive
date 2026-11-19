/// Lista de backups en Drive para restaurar (latest primero). Al elegir uno,
/// confirma y sobrescribe la DB activa, luego recarga.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
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
    final ok = await widget.svc.restore(e.id, widget.settings);
    if (!mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text(ok ? t.restoreDone : t.backupFailed)));
    if (ok) {
      widget.onReloadDb();
      nav.popUntil((r) => r.isFirst); // volver al inicio con la DB recargada
    }
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
