/// Revisar antes de importar el CSV de SSI: lista de inmersiones con
/// checkbox. Verde = nueva (marcada); ámbar = parece que ya está (desmarcada,
/// pero se puede marcar: el emparejamiento es aproximado). Al importar va a
/// la lista de buceos ya refrescada.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/ssi_csv_import.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/services/home_navigation.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/features/settings/widgets/import_dive_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ImportSsiScreen extends StatefulWidget {
  final DivemateDb db;
  final List<SsiPlanEntry> entries;
  const ImportSsiScreen({super.key, required this.db, required this.entries});

  @override
  State<ImportSsiScreen> createState() => _ImportSsiScreenState();
}

class _ImportSsiScreenState extends State<ImportSsiScreen> {
  List<SsiPlanEntry> get _entries => widget.entries;
  // Índices marcados (las filas no tienen id propio).
  late final Set<int> _sel = {
    for (var i = 0; i < _entries.length; i++)
      if (!_entries[i].duplicate) i
  };

  void _toggleAll() => setState(() {
        if (_sel.length == _entries.length) {
          _sel.clear();
        } else {
          _sel.addAll(List.generate(_entries.length, (i) => i));
        }
      });

  Future<void> _apply() async {
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dives = [
      for (var i = 0; i < _entries.length; i++)
        if (_sel.contains(i)) _entries[i].dive
    ];
    final added = await withProgressBar(
        context, (p) => applySsiImport(widget.db, dives, onProgress: p));
    bumpDataRevision();
    requestDivesList();
    nav.popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(t.importSsiDone(added))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dups = _entries.where((e) => e.duplicate).length;
    final allSel = _sel.length == _entries.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.importSsi),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: allSel ? t.deselectAll : t.selectAll,
              icon: Icon(allSel ? Icons.deselect : Icons.select_all),
              onPressed: _toggleAll,
            ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(child: Text(t.nothingToImport))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(t.importSsiHeader(_entries.length - dups, dups),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final d = _entries[i].dive;
                    return ImportDiveTile(
                      place: [d.site, d.country].whereType<String>().join(', '),
                      date: d.date,
                      minutes: d.minutes,
                      depth: d.depth,
                      duplicate: _entries[i].duplicate,
                      duplicateText: t.importSsiDuplicate,
                      duplicateSelectable: true,
                      selected: _sel.contains(i),
                      onChanged: (v) =>
                          setState(() => v ? _sel.add(i) : _sel.remove(i)),
                    );
                  },
                ),
              ),
            ]),
      bottomNavigationBar: _entries.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, 16 + MediaQuery.paddingOf(context).bottom),
              child: FilledButton.icon(
                onPressed: _sel.isEmpty ? null : _apply,
                icon: const Icon(Icons.download),
                label: Text('${t.importDivesAction} (${_sel.length})'),
              ),
            ),
    );
  }
}
