/// Sync sheet: status, last sync, notice about another device
/// open and the relevant action (sync, update or resolve a
/// divergence by choosing a version).
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/services/sync_controller.dart';
import 'package:pandive/features/sync/widgets/sync_indicator.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SyncSheet extends StatelessWidget {
  const SyncSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: syncController,
      builder: (context, _) {
        final c = syncController;
        final busy = c.status == SyncStatus.syncing;
        final locale = Localizations.localeOf(context).languageCode;
        final other = c.otherActive;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.syncTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(syncStatusText(t, c.status)),
                if (c.lastSync != null)
                  Text(t.syncLast(DateFormat.Hm(locale).format(c.lastSync!)),
                      style: Theme.of(context).textTheme.bodySmall),
                if (other != null) ...[
                  const SizedBox(height: 12),
                  _Note(
                    icon: Icons.devices_other,
                    text: t.syncOtherActive(other.device,
                        DateTime.now().toUtc().difference(other.time).inMinutes),
                  ),
                ],
                const SizedBox(height: 16),
                ..._actions(context, t, c, busy),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actions(
      BuildContext context, AppLocalizations t, SyncController c, bool busy) {
    void run(Future<void> Function() f) {
      Navigator.of(context).pop();
      f();
    }

    if (c.status == SyncStatus.diverged) {
      return [
        _Note(icon: Icons.sync_problem, text: t.syncDivergedExplain),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: () => run(() => c.resolve(keepLocal: true)),
            child: Text(t.syncKeepLocal)),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: () => run(() => c.resolve(keepLocal: false)),
            child: Text(t.syncKeepRemote)),
      ];
    }
    if (c.status == SyncStatus.pendingRemote) {
      return [
        FilledButton.icon(
            onPressed: () => run(() => c.sync(force: true)),
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(t.syncApplyRemote)),
      ];
    }
    return [
      FilledButton.icon(
          onPressed: busy ? null : () => run(() => c.sync(force: true)),
          icon: const Icon(Icons.sync),
          label: Text(t.syncNow)),
    ];
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      );
}
