/// Elegir qué buceos de un .ddb externo (abierto en solo lectura) importar al
/// logbook. Verde = nuevo (marcado por defecto); ámbar = coincide en hora con
/// uno existente (se ignora). Al terminar muestra un resumen.
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/settings/logic/import_dives.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ImportDdbDivesScreen extends StatefulWidget {
  final DivemateDb target; // logbook propio
  final DivemateDb source; // .ddb abierto en solo lectura
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
    final r = await withProgress(context, t.working,
        () => importDivesFromDb(widget.target, widget.source, only: _sel));
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
                  itemBuilder: (context, i) => _ImportDiveTile(
                    entry: _entries[i],
                    selected: _sel.contains(_entries[i].dive.id),
                    onChanged: (v) => setState(() => v
                        ? _sel.add(_entries[i].dive.id)
                        : _sel.remove(_entries[i].dive.id)),
                  ),
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

/// Fila: checkbox + sitio + fecha/duración/profundidad; color según estado.
class _ImportDiveTile extends StatelessWidget {
  final DdbImportEntry entry;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const _ImportDiveTile(
      {required this.entry, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final d = entry.dive;
    final dup = entry.duplicate;
    final place = [d.place, d.country]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');
    final info = [
      DateFormat('dd/MM/yyyy HH:mm', locale).format(d.date!),
      if (d.durationMin != null) '${d.durationMin!.round()} min',
      if (d.maxDepth != null)
        '${NumberFormat('0.0', locale).format(d.maxDepth)} m',
    ].join('   ');
    return CheckboxListTile(
      value: dup ? false : selected,
      onChanged: dup ? null : (v) => onChanged(v == true),
      tileColor:
          (dup ? Colors.amber : Colors.green).withValues(alpha: 0.12),
      title: Text(place.isEmpty ? t.dive : place,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(dup ? '$info\n${t.importDiveDuplicate}' : info),
      isThreeLine: dup,
      secondary: Icon(dup ? Icons.block : Icons.add_circle_outline),
    );
  }
}
