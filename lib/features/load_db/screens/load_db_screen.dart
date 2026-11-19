/// Pantalla inicial cuando no hay base de datos cargada: permite elegir un
/// fichero .ddb de DiveMate. Se copia a los documentos de la app para tener
/// acceso estable (lectura/escritura) después.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/features/load_db/widgets/load_db_buttons.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Error al abrir la DB activa, para mostrarlo localizado en la pantalla.
enum DbLoadError { invalid, openFailed }

class LoadDbScreen extends StatefulWidget {
  final Settings settings;
  final DbLoadError? error;
  final String? errorDetail; // detalle para openFailed
  final Future<void> Function(String path) onLoaded;

  const LoadDbScreen({
    super.key,
    required this.settings,
    required this.error,
    this.errorDetail,
    required this.onLoaded,
  });
  @override
  State<LoadDbScreen> createState() => _LoadDbScreenState();
}

class _LoadDbScreenState extends State<LoadDbScreen> {
  bool _busy = false;
  String? _localError;

  // Ejecuta [action] con el flag de ocupado y captura errores localizados.
  Future<void> _run(
      Future<void> Function() action, String Function(String) err) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => (_busy = false, _localError = err('$e')));
    }
  }

  Future<String> _newDbPath() async {
    final docs = (await getApplicationDocumentsDirectory()).path;
    return '$docs/logbook-${DateTime.now().millisecondsSinceEpoch}.ddb';
  }

  void _pick() => _run(() async {
        final res = await FilePicker.platform.pickFiles(withData: false);
        final path = res?.files.single.path;
        if (path == null) return setState(() => _busy = false);
        final docs = await getApplicationDocumentsDirectory();
        final dest = File('${docs.path}/logbook.ddb');
        await File(path).copy(dest.path);
        await widget.onLoaded(dest.path);
      }, (e) => AppLocalizations.of(context).errorLoad(e));

  void _createNew() => _run(() async {
        final dest = await _newDbPath();
        DivemateDb.createEmpty(dest).close();
        await widget.onLoaded(dest);
      }, (e) => AppLocalizations.of(context).errorCreate(e));

  // Importa un .ssrf creando un logbook nuevo y volcándolo en él.
  void _importSsrf() => _run(() async {
        final res = await FilePicker.platform.pickFiles(withData: false);
        final path = res?.files.single.path;
        if (path == null) return setState(() => _busy = false);
        final xml = await File(path).readAsString();
        final dest = await _newDbPath();
        final db = DivemateDb.createEmpty(dest);
        if (!mounted) return db.close();
        await importSsrfWithProgress(context, db, xml);
        db.close();
        await widget.onLoaded(dest);
      }, (e) => AppLocalizations.of(context).errorCreate(e));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final err = _localError ??
        switch (widget.error) {
          DbLoadError.invalid => t.invalidDb,
          DbLoadError.openFailed => t.dbOpenFailed(widget.errorDetail ?? ''),
          null => null,
        };
    return Scaffold(
      appBar: AppBar(title: const Text('PanDive')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/logo/pandive_splash.png',
                    width: 128, height: 128),
              ),
              const SizedBox(height: 16),
              Text(
                t.loadHeadline,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t.loadSubtitle,
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
              LoadDbButtons(
                busy: _busy,
                onPick: _pick,
                onCreate: _createNew,
                onImport: _importSsrf,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
