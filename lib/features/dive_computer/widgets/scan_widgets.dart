/// Widgets de la pantalla de escaneo BLE: fila de dispositivo y vista de error.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/services/dive_computer.dart';

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
      trailing: d.likely ? const Chip(label: Text('Buceo')) : null,
      onTap: onTap,
    );
  }
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
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
