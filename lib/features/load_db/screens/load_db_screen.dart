/// Pantalla inicial cuando no hay base de datos cargada: permite elegir un
/// fichero .ddb de DiveMate. Se copia a los documentos de la app para tener
/// acceso estable (lectura/escritura) después.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';

class LoadDbScreen extends StatefulWidget {
  final Settings settings;
  final String? error;
  final Future<void> Function(String path) onLoaded;

  const LoadDbScreen({
    super.key,
    required this.settings,
    required this.error,
    required this.onLoaded,
  });

  @override
  State<LoadDbScreen> createState() => _LoadDbScreenState();
}

class _LoadDbScreenState extends State<LoadDbScreen> {
  bool _busy = false;
  String? _localError;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      final res = await FilePicker.platform.pickFiles(withData: false);
      if (res == null || res.files.single.path == null) {
        setState(() => _busy = false);
        return;
      }
      final picked = File(res.files.single.path!);
      final docs = await getApplicationDocumentsDirectory();
      final dest = File('${docs.path}/logbook.ddb');
      await picked.copy(dest.path);
      await widget.onLoaded(dest.path);
    } catch (e) {
      setState(() {
        _busy = false;
        _localError = 'Error al cargar: $e';
      });
    }
  }

  Future<void> _createNew() async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      // Nombre único: no sobrescribe un logbook existente.
      final dest = File(
          '${docs.path}/logbook-${DateTime.now().millisecondsSinceEpoch}.ddb');
      DivemateDb.createEmpty(dest.path).close();
      await widget.onLoaded(dest.path);
    } catch (e) {
      setState(() {
        _busy = false;
        _localError = 'Error al crear: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = _localError ?? widget.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Pandive')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/logo/pandive_logo.png',
                    width: 128, height: 128),
              ),
              const SizedBox(height: 16),
              Text(
                'Carga tu logbook',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona un fichero .ddb de DiveMate para empezar.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (err != null) ...[
                Text(
                  err,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: const Text('Elegir fichero .ddb'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _createNew,
                icon: const Icon(Icons.add),
                label: const Text('Crear logbook nuevo (vacío)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
