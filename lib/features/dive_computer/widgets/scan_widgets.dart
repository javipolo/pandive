/// Widgets de la pantalla de escaneo BLE: fila de dispositivo y vista de error.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/services/dive_computer.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ScannedDeviceTile extends StatelessWidget {
  final ScannedDevice device;
  final VoidCallback onTap;
  const ScannedDeviceTile({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = device;
    return ListTile(
      leading: Icon(
        d.likely ? Icons.scuba_diving : Icons.bluetooth,
        color: d.likely ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(d.name),
      subtitle: Text('${d.id}   ·   ${d.rssi} dBm'),
      trailing: d.likely
          ? Chip(label: Text(AppLocalizations.of(context).diveChip))
          : null,
      onTap: onTap,
    );
  }
}

/// Hoja de acciones al tocar un ordenador. Devuelve 'download', 'sync', 'mark'
/// o null (cancelar).
Future<String?> showDiveComputerActionSheet(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.sync),
          title: Text(t.sync),
          subtitle: Text(t.syncSub),
          onTap: () => Navigator.pop(context, 'sync'),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(t.actionDownload),
          subtitle: Text(t.actionDownloadSub),
          onTap: () => Navigator.pop(context, 'download'),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(t.actionMarkImported),
          subtitle: Text(t.actionMarkImportedSub),
          onTap: () => Navigator.pop(context, 'mark'),
        ),
      ]),
    ),
  );
}

/// Pregunta cuántas inmersiones recientes comprobar al sincronizar.
Future<int?> askSyncCount(BuildContext context) {
  final t = AppLocalizations.of(context);
  var n = 5;
  return showDialog<int>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (c, setDlg) => AlertDialog(
        title: Text(t.sync),
        content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => setDlg(() => n = (n - 1).clamp(1, 50))),
          Text('$n', style: Theme.of(c).textTheme.titleLarge),
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setDlg(() => n = (n + 1).clamp(1, 50))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, n), child: Text(t.sync)),
        ],
      ),
    ),
  );
}

/// Pregunta si guardar el ordenador recién escaneado (checkbox marcado por
/// defecto). Devuelve true=guardar, false=no guardar, null=cancelar.
Future<bool?> showSaveComputerDialog(BuildContext context, String name) {
  final t = AppLocalizations.of(context);
  var save = true;
  return showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (c, setDlg) => AlertDialog(
        title: Text(name),
        content: CheckboxListTile(
          value: save,
          onChanged: (v) => setDlg(() => save = v ?? false),
          contentPadding: EdgeInsets.zero,
          title: Text(t.saveComputer),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, save),
              child: Text(t.continueLabel)),
        ],
      ),
    ),
  );
}

class ScanErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ScanErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).retry)),
          ],
        ),
      ),
    );
  }
}
