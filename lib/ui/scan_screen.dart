/// Escaneo BLE: busca ordenadores de buceo cercanos y los lista.
/// Fase 2 hito B. La descarga (al tocar un dispositivo) llega en el hito C.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dive_computer.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _svc = DiveComputerService();
  final Map<String, ScannedDevice> _devices = {};
  StreamSubscription<ScannedDevice>? _sub;
  String? _error;
  bool _scanning = false;
  bool _permissionOk = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _devices.clear();
    });
    final ok = await _svc.requestBlePermissions();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _permissionOk = false;
        _error = 'Faltan permisos de Bluetooth. Concédelos en Ajustes para '
            'poder buscar el ordenador de buceo.';
      });
      return;
    }
    setState(() {
      _permissionOk = true;
      _scanning = true;
    });
    _sub = _svc.scan().listen(
      (d) {
        setState(() => _devices[d.id] = d);
      },
      onError: (e) {
        setState(() {
          _scanning = false;
          _error = 'Error de escaneo: $e';
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<ScannedDevice> get _sorted {
    final list = _devices.values.toList();
    list.sort((a, b) {
      if (a.likely != b.likely) return a.likely ? -1 : 1;
      return b.rssi.compareTo(a.rssi);
    });
    return list;
  }

  void _onTap(ScannedDevice d) {
    // Hito C: aquí irá la conexión + descarga.
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(d.name),
        content: const Text(
            'La descarga de inmersiones llega en el siguiente paso (hito C). '
            'De momento el escaneo ya detecta el ordenador.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vale'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = _sorted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar ordenador'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reescanear',
              onPressed: _start,
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth_disabled, size: 56),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _start,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_permissionOk)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _scanning
                          ? 'Buscando… enciende el ordenador y activa su Bluetooth.'
                          : 'Escaneo detenido.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Expanded(
                  child: devices.isEmpty
                      ? const Center(child: Text('Ningún dispositivo todavía'))
                      : ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => _tile(devices[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _tile(ScannedDevice d) {
    return ListTile(
      leading: Icon(
        d.likely ? Icons.scuba_diving : Icons.bluetooth,
        color: d.likely ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(d.name),
      subtitle: Text('${d.id}   ·   ${d.rssi} dBm'),
      trailing: d.likely
          ? const Chip(label: Text('Buceo'))
          : null,
      onTap: () => _onTap(d),
    );
  }
}
