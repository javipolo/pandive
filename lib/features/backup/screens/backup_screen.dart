/// Copia de seguridad en Google Drive: conectar cuenta, backup manual, toggle
/// de backup diario automático y acceso a la restauración.
library;

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _svc.signInSilently().then((_) {
      if (mounted) setState(() {});
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
    try {
      if (_svc.connected) {
        await _svc.signOut();
      } else {
        await _svc.signIn();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _busy = false);
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
            title: Text(connected ? (_svc.email ?? '') : t.notConnected),
            trailing: _busy
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
            value: widget.settings.autoBackup,
            onChanged: connected
                ? (v) => setState(() => widget.settings.setAutoBackup(v))
                : null,
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
