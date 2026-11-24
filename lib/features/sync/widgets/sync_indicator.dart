/// Icono de estado de la sincronización en la barra superior (oculto si está
/// desactivada). Punto rojo si hay divergencia u otro dispositivo abierto.
/// Al pulsarlo abre [SyncSheet].
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/services/sync_controller.dart';
import 'package:pandive/features/sync/widgets/sync_sheet.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: syncController,
      builder: (context, _) {
        final c = syncController;
        if (c.status == SyncStatus.off) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final (icon, color) = switch (c.status) {
          SyncStatus.synced => (Icons.cloud_done_outlined, null),
          SyncStatus.syncing => (Icons.sync, null),
          SyncStatus.pendingRemote => (Icons.cloud_download_outlined, scheme.primary),
          SyncStatus.diverged => (Icons.sync_problem, scheme.error),
          _ => (Icons.cloud_off_outlined, null),
        };
        return IconButton(
          tooltip: syncStatusText(AppLocalizations.of(context), c.status),
          icon: Badge(
            isLabelVisible:
                c.status == SyncStatus.diverged || c.otherActive != null,
            child: Icon(icon, color: color),
          ),
          onPressed: () => showModalBottomSheet<void>(
              context: context, builder: (_) => const SyncSheet()),
        );
      },
    );
  }
}

String syncStatusText(AppLocalizations t, SyncStatus s) => switch (s) {
      SyncStatus.synced => t.syncStatusSynced,
      SyncStatus.syncing => t.syncStatusSyncing,
      SyncStatus.pendingRemote => t.syncStatusPending,
      SyncStatus.diverged => t.syncStatusDiverged,
      SyncStatus.offline => t.syncStatusOffline,
      SyncStatus.off => '',
    };
