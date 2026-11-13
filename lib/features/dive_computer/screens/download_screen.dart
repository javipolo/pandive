/// Descarga las inmersiones de un dispositivo y las muestra (hito C.1: todavía
/// no se guardan en el .ddb; eso es el hito C.2).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/dive_computer.dart';

class DownloadScreen extends StatefulWidget {
  final ScannedDevice device;
  const DownloadScreen({super.key, required this.device});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _svc = DiveComputerService();
  final _dateFmt = DateFormat('d MMM yyyy, HH:mm', 'es');
  late Future<DownloadResult> _future;
  late final (String, String)? _model;

  @override
  void initState() {
    super.initState();
    _model = modelForDeviceName(widget.device.name);
    _future = _download();
  }

  Future<DownloadResult> _download() async {
    final m = _model;
    if (m == null) {
      return DownloadResult(
          error: 'Modelo no reconocido por el nombre "${widget.device.name}".');
    }
    return _svc.download(
      vendor: m.$1,
      product: m.$2,
      address: widget.device.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _model != null ? '${_model.$1} ${_model.$2}' : widget.device.name;
    return Scaffold(
      appBar: AppBar(title: Text('Descargar · $title')),
      body: FutureBuilder<DownloadResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _Progress();
          }
          final res = snap.data;
          if (snap.hasError) return _error('${snap.error}');
          if (res == null || !res.ok) return _error(res?.error ?? 'Error');
          return _list(res.dives);
        },
      ),
    );
  }

  Widget _error(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _future = _download()),
              child: const Text('Reintentar'),
            ),
          ]),
        ),
      );

  Widget _list(List<DownloadedDive> dives) {
    if (dives.isEmpty) {
      return const Center(child: Text('El ordenador no devolvió inmersiones'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${dives.length} inmersiones descargadas (aún sin guardar)',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: dives.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _tile(dives[i]),
          ),
        ),
      ],
    );
  }

  Widget _tile(DownloadedDive d) {
    final stats = [
      if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
      if (d.divetimeSec != null) '${(d.divetimeSec! / 60).round()} min',
      '${d.samples.length} muestras',
    ].join('   ');
    return ListTile(
      leading: const Icon(Icons.download_done),
      title: Text(d.datetime != null ? _dateFmt.format(d.datetime!) : 'Inmersión'),
      subtitle: Text(stats),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Conectando y descargando…\nMantén el ordenador cerca y encendido.',
              textAlign: TextAlign.center),
        ]),
      );
}
