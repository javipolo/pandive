/// Previsualiza un .ddb en solo lectura (lista de inmersiones) sin tocar la DB
/// activa. Desde aquí se puede rellenar buceos o usarlo como base de datos.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/dives/widgets/month_grouped_dives.dart';
import 'package:pandive/features/settings/screens/fill_from_ddb_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PreviewDdbScreen extends StatefulWidget {
  final String path;
  final Settings settings;
  final DivemateDb db; // base de datos activa (para rellenar)
  final void Function(String path) onReplace;
  const PreviewDdbScreen({
    super.key,
    required this.path,
    required this.settings,
    required this.db,
    required this.onReplace,
  });

  @override
  State<PreviewDdbScreen> createState() => _PreviewDdbScreenState();
}

class _PreviewDdbScreenState extends State<PreviewDdbScreen> {
  DivemateDb? _preview;
  List<Dive> _dives = const [];
  Set<int> _cave = const {};

  @override
  void initState() {
    super.initState();
    try {
      final db = DivemateDb.open(widget.path, readOnly: true);
      if (db.looksValid) {
        _preview = db;
        _dives = db.listDives();
        _cave = db.diveIdsWithTag('cave');
      } else {
        db.close();
      }
    } catch (_) {/* fichero inválido */}
  }

  @override
  void dispose() {
    _preview?.close();
    super.dispose();
  }

  Future<void> _useThis() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.replaceDbConfirm,
        confirmLabel: t.replaceDb)) {
      return;
    }
    widget.onReplace(widget.path);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final ok = _preview != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.previewDdb),
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
      ),
      body: !ok
          ? Center(child: Text(t.invalidDb))
          : _dives.isEmpty
              ? Center(child: Text(t.noResults))
              : MonthGroupedDives(
                  dives: _dives,
                  settings: widget.settings,
                  caveIds: _cave,
                  onOpen: (_) {}),
      bottomNavigationBar: !ok
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(t.replaceDb),
                    onPressed: _useThis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(t.fillAction),
                    onPressed: () => openFillFromDdb(context, widget.db,
                        sourcePath: widget.path),
                  ),
                ),
              ]),
            ),
    );
  }
}
