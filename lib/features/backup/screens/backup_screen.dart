/// Copia de seguridad en Google Drive: conectar cuenta, backup manual, toggle
/// de backup diario automático y acceso a la restauración.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/services/backup_worker.dart';
import 'package:pandive/core/services/drive_backup.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/backup/widgets/restore_list.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BackupScreen extends StatefulWidget {
  final Settings settings;
  final VoidCallback onReloadDb;
  const BackupScreen(
      {super.key, required this.settings, required this.onReloadDb});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _svc = DriveBackupService();
  bool _busy = false;

  bool _connecting = true; // reconectando en silencio al abrir

  @override
  void initState() {
    super.initState();
    _svc.signInSilently().then((_) {
      if (mounted) setState(() => _connecting = false);
    });
  }

  Future<void> _run(Future<bool> Function() action, String okMsg) async {
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? okMsg : t.backupFailed)));
  }

  Future<void> _toggleAccount() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    try {
      if (_svc.connected) {
        await _svc.signOut();
        await cancelAutoBackup();
      } else if (!DriveBackupService.configured) {
        messenger.showSnackBar(SnackBar(content: Text(t.driveNotConfigured)));
      } else {
        await _svc.signIn(browserDoneText: t.oauthBrowserDone);
        // Al conectar, activar el backup automático por defecto.
        if (_svc.connected) {
          await widget.settings.setAutoBackup(true);
          await registerAutoBackup();
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleAutoBackup(bool v) async {
    await widget.settings.setAutoBackup(v);
    await (v ? registerAutoBackup() : cancelAutoBackup());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final connected = _svc.connected;
    return Scaffold(
      appBar: AppBar(title: Text(t.backupDrive)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(connected
                ? (_svc.email ?? '')
                : (_connecting ? t.connecting : t.notConnected)),
            trailing: (_busy || _connecting)
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _toggleAccount,
                    child: Text(connected ? t.disconnect : t.connectAccount),
                  ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(t.autoBackupDaily),
            subtitle: Text(t.autoBackupHint),
            value: widget.settings.autoBackup,
            onChanged: connected ? _toggleAutoBackup : null,
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(t.backupNow),
            enabled: connected && !_busy,
            onTap: () => _run(() => _svc.backupNow(widget.settings), t.backupDone),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(t.restore),
            enabled: connected && !_busy,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RestoreList(
                  svc: _svc,
                  settings: widget.settings,
                  onReloadDb: widget.onReloadDb),
            )),
          ),
        ],
      ),
    );
  }
}
