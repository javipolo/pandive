/// Dive sites tab: list grouped by country + create/edit, with
/// multiple selection to export (JSON) or delete.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/features/dives/screens/filtered_dives_screen.dart';
import 'package:pandive/features/sites/logic/export_sites.dart';
import 'package:pandive/features/sites/screens/site_edit_screen.dart';
import 'package:pandive/features/sites/screens/site_info_screen.dart';
import 'package:pandive/features/sites/widgets/sites_grouped_list.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'package:pandive/core/platform.dart';

class SitesTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String query;
  final bool collapseAll;
  final bool sortByDives;
  const SitesTab(
      {super.key,
      required this.db,
      required this.settings,
      this.query = '',
      this.collapseAll = false,
      this.sortByDives = false});

  @override
  State<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends State<SitesTab> {
  late List<DiveSite> _sites = widget.db.listSites();
  bool _select = false;
  final Set<int> _sel = {};

  void _reload() => setState(() => _sites = widget.db.listSites());

  void _exitSel() => setState(() {
        _select = false;
        _sel.clear();
      });

  void _toggle(DiveSite s) => setState(() {
        if (!_sel.remove(s.id)) _sel.add(s.id);
        if (_sel.isEmpty) _select = false;
      });

  // "All" = those visible with the current search.
  List<DiveSite> get _visible => filterSites(_sites, widget.query);

  bool get _allSelected {
    final v = _visible;
    return v.isNotEmpty && v.every((s) => _sel.contains(s.id));
  }

  void _toggleAll() => setState(() {
        final ids = _visible.map((s) => s.id);
        _allSelected ? _sel.removeAll(ids) : _sel.addAll(ids);
      });

  List<DiveSite> get _picked =>
      _sites.where((s) => _sel.contains(s.id)).toList();

  Future<void> _exportSel() async {
    final t = AppLocalizations.of(context);
    final picked = _picked;
    final f =
        await withProgress(context, t.exporting, () => writeSitesJson(picked));
    await shareOrSaveFile(f);
    _exitSel();
  }

  Future<void> _deleteSel() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deleteConfirm(_sel.length),
        confirmLabel: t.delete)) {
      return;
    }
    for (final id in _sel) {
      widget.db.deleteSite(id);
    }
    bumpDataRevision();
    _exitSel();
    _reload();
  }

  Future<void> _new() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SiteEditScreen(db: widget.db, site: null),
    ));
    if (changed == true && mounted) _reload();
  }

  Future<void> _dives(DiveSite site) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FilteredDivesScreen(
              db: widget.db,
              settings: widget.settings,
              title: site.name ?? '',
              loader: () => widget.db.listDivesBySite(site.id),
            )));
    if (mounted) _reload();
  }

  Future<void> _info(DiveSite site) async {
    final idx = _sites.indexWhere((s) => s.id == site.id);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SiteInfoScreen(
          db: widget.db, sites: _sites, initialIndex: idx < 0 ? 0 : idx),
    ));
    if (mounted) _reload(); // editing/deleting inside may have changed things
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: _select
          ? null
          : FloatingActionButton(
              onPressed: _new,
              child: const Icon(Icons.add),
            ),
      body: Column(children: [
        if (_select)
          SelectionBar(count: _sel.length, onClose: _exitSel, actions: [
            IconButton(
              tooltip: _allSelected ? t.deselectAll : t.selectAll,
              icon: Icon(_allSelected ? Icons.deselect : Icons.select_all),
              onPressed: _toggleAll,
            ),
            if (!isWeb)
              IconButton(
                tooltip: t.exportSites,
                icon: const Icon(Icons.ios_share),
                onPressed: _sel.isEmpty ? null : _exportSel,
              ),
            IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _sel.isEmpty ? null : _deleteSel,
            ),
          ]),
        Expanded(
          child: SitesGroupedList(
              sites: _sites,
              onTap: _dives,
              onInfo: _info,
              externalQuery: widget.query,
              collapseAll: widget.collapseAll,
              sortByDives: widget.sortByDives,
              selectedIds: _sel,
              selectMode: _select,
              onToggle: _toggle,
              onLongPress: (s) => setState(() {
                    _select = true;
                    _sel.add(s.id);
                  })),
        ),
      ]),
    );
  }
}
