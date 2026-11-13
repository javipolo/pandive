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

/// Hoja de acciones al tocar un ordenador: descargar o marcar como importado.
/// Devuelve false = descargar, true = marcar (baseline), null = cancelar.
Future<bool?> showDiveComputerActionSheet(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(t.actionDownload),
          subtitle: Text(t.actionDownloadSub),
          onTap: () => Navigator.pop(context, false),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(t.actionMarkImported),
          subtitle: Text(t.actionMarkImportedSub),
          onTap: () => Navigator.pop(context, true),
        ),
      ]),
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
