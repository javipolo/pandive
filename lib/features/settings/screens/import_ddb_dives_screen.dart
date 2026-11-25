/// Choose which dives of an external .ddb (opened read-only) to import into the
/// logbook. Green = new (ticked by default); amber = matches the time of
/// an existing one (ignored). Shows a summary when done.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/import_progress.dart';
import 'package:pandive/features/settings/logic/import_dives.dart';
import 'package:pandive/features/settings/widgets/import_dive_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ImportDdbDivesScreen extends StatefulWidget {
  final DivemateDb target; // logbook propio
  final DivemateDb source; // .ddb opened read-only
  const ImportDdbDivesScreen(
      {super.key, required this.target, required this.source});

  @override
  State<ImportDdbDivesScreen> createState() => _ImportDdbDivesScreenState();
}

class _ImportDdbDivesScreenState extends State<ImportDdbDivesScreen> {
  late final List<DdbImportEntry> _entries =
      planDdbImport(widget.target, widget.source);
  late final Set<int> _sel = {
    for (final e in _entries) if (!e.duplicate) e.dive.id
  };

  int get _newCount => _entries.where((e) => !e.duplicate).length;

  void _toggleAll() => setState(() {
        if (_sel.length == _newCount) {
          _sel.clear();
        } else {
          _sel.addAll([for (final e in _entries) if (!e.duplicate) e.dive.id]);
        }
      });

  Future<void> _apply() async {
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    if (!await confirmDialog(context, t.importDivesConfirm(_sel.length),
        confirmLabel: t.importDivesAction)) {
      return;
    }
    if (!mounted) return;
    final r = await withProgressBar(
        context,
        (p) => importDivesFromDb(widget.target, widget.source,
            only: _sel, onProgress: p));
    bumpDataRevision();
    if (!mounted) return;
    await _showSummary(r);
    nav.pop(r);
  }

  Future<void> _showSummary(DdbImportResult r) {
    final t = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.importSummaryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.importSummaryImported(r.imported)),
            Text(t.importSummaryDuplicates(r.duplicates)),
            Text(t.importSummaryNotSelected(r.notSelected)),
            Text(t.importSummaryNewSites(r.newSites)),
            Text(t.importSummaryNewBuddies(r.newBuddies)),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dups = _entries.length - _newCount;
    final allSel = _newCount > 0 && _sel.length == _newCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.importDivesAction),
        actions: [
          if (_newCount > 0)
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
                child: Text(t.importDivesHeader(_newCount, dups),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    final d = e.dive;
                    return ImportDiveTile(
                      place: [d.place, d.country]
                          .whereType<String>()
                          .where((x) => x.isNotEmpty)
                          .join(', '),
                      date: d.date!,
                      minutes: d.durationMin,
                      depth: d.maxDepth,
                      duplicate: e.duplicate,
                      duplicateText: t.importDiveDuplicate,
                      selected: _sel.contains(d.id),
                      onChanged: (v) => setState(
                          () => v ? _sel.add(d.id) : _sel.remove(d.id)),
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
