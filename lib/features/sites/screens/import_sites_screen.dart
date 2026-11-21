/// Previsualización del import de sitios: lista de altas/modificaciones con
/// checkbox (todo marcado), color por acción; al confirmar aplica los elegidos.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/sites/logic/site_import.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ImportSitesScreen extends StatefulWidget {
  final DivemateDb db;
  final List<SiteImport> entries;
  const ImportSitesScreen(
      {super.key, required this.db, required this.entries});

  @override
  State<ImportSitesScreen> createState() => _ImportSitesScreenState();
}

class _ImportSitesScreenState extends State<ImportSitesScreen> {
  late final Set<int> _sel = {
    for (var i = 0; i < widget.entries.length; i++) i
  };

  String _fieldLabel(String key, AppLocalizations t) => switch (key) {
        'Country' => t.fieldCountry,
        'Region' => t.fieldRegion,
        'Lat' => t.latitude,
        'Lon' => t.longitude,
        _ => key,
      };

  Future<void> _apply() async {
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final chosen = [
      for (var i = 0; i < widget.entries.length; i++)
        if (_sel.contains(i)) widget.entries[i]
    ];
    if (chosen.isEmpty) return;
    final add = chosen.where((e) => e.action == SiteImportAction.add).length;
    final mod = chosen.length - add;
    if (!await confirmDialog(context, t.importSitesConfirm(add, mod),
        confirmLabel: t.importSites)) {
      return;
    }
    if (!mounted) return;
    final n = await withProgress(
        context, t.working, () async => applySiteImport(widget.db, chosen));
    bumpDataRevision();
    nav.pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.importSites)),
      body: widget.entries.isEmpty
          ? Center(child: Text(t.nothingToImport))
          : ListView.builder(
              itemCount: widget.entries.length,
              itemBuilder: (context, i) {
                final e = widget.entries[i];
                final isAdd = e.action == SiteImportAction.add;
                return CheckboxListTile(
                  value: _sel.contains(i),
                  onChanged: (v) => setState(
                      () => v == true ? _sel.add(i) : _sel.remove(i)),
                  tileColor: (isAdd ? Colors.green : Colors.amber)
                      .withValues(alpha: 0.12),
                  title: Text(e.name),
                  subtitle: Text(
                      '${isAdd ? t.importAdd : t.importModify} · '
                      '${e.changedKeys.map((k) => _fieldLabel(k, t)).join(', ')}'),
                  secondary: Icon(isAdd ? Icons.add_location_alt : Icons.edit_location_alt),
                );
              },
            ),
      bottomNavigationBar: widget.entries.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, 16 + MediaQuery.paddingOf(context).bottom),
              child: FilledButton.icon(
                onPressed: _sel.isEmpty ? null : _apply,
                icon: const Icon(Icons.download),
                label: Text('${t.importSites} (${_sel.length})'),
              ),
            ),
      backgroundColor: cs.surface,
    );
  }
}
