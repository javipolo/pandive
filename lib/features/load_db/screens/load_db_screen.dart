/// Initial screen when no database is loaded: lets you pick a
/// DiveMate .ddb file (the app works on its own copy, see
/// `load_db_files.dart`), create an empty one or import a .ssrf.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/features/load_db/logic/load_db_files.dart';
import 'package:pandive/features/load_db/widgets/load_db_buttons.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Error opening the active DB, to show it localised on the screen.
enum DbLoadError { invalid, openFailed }

class LoadDbScreen extends StatefulWidget {
  final Settings settings;
  final DbLoadError? error;
  final String? errorDetail; // detail for openFailed
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

  // Runs [action] with the busy flag and catches localised errors.
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

  void _pick() => _run(() async {
        final dest = await pickDdbCopy();
        if (dest == null) return setState(() => _busy = false);
        await widget.onLoaded(dest);
      }, (e) => AppLocalizations.of(context).errorLoad(e));

  void _createNew() => _run(() async {
        final dest = await newDbPath();
        DivemateDb.createEmpty(dest).close();
        await widget.onLoaded(dest);
      }, (e) => AppLocalizations.of(context).errorCreate(e));

  // Imports a .ssrf creating a new logbook and dumping it into it.
  void _importSsrf() => _run(() async {
        final xml = await pickTextFile();
        if (xml == null) return setState(() => _busy = false);
        final dest = await newDbPath();
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
