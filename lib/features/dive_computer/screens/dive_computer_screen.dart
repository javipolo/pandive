/// Pantalla de ordenador de buceo. Fase 2 hito A: muestra que el enlace con
/// libdivecomputer funciona (nº y lista de modelos soportados). El escaneo y la
/// descarga BLE llegan en los hitos siguientes.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/services/dive_computer.dart';
import 'scan_screen.dart';

class DiveComputerScreen extends StatefulWidget {
  const DiveComputerScreen({super.key});

  @override
  State<DiveComputerScreen> createState() => _DiveComputerScreenState();
}

class _DiveComputerScreenState extends State<DiveComputerScreen> {
  final _svc = DiveComputerService();
  final _searchCtrl = TextEditingController();
  late Future<(int, List<String>)> _future;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(int, List<String>)> _load() async {
    final count = await _svc.supportedCount();
    final list = await _svc.supportedList();
    return (count, list);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ordenador de buceo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        ),
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('Buscar'),
      ),
      body: FutureBuilder<(int, List<String>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al hablar con libdivecomputer:\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final (count, list) = snap.data!;
          final shown = _filter.isEmpty
              ? list
              : list
                  .where((e) => e.toLowerCase().contains(_filter.toLowerCase()))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.memory),
                    title: Text('$count modelos soportados'),
                    subtitle: const Text(
                        'libdivecomputer enlazado correctamente (nativo).'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Filtrar modelos…',
                  leading: const Icon(Icons.search),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.scuba_diving_outlined),
                    title: Text(shown[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
