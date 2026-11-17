/// Pestaña de inmersiones: lista por mes, añadir, selección en lote, búsqueda.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/dives/logic/adjust_time.dart';
import 'package:pandive/features/dives/widgets/add_dive_sheet.dart';
import 'package:pandive/features/dives/widgets/dives_selection_bar.dart';
import 'package:pandive/features/dives/widgets/month_grouped_dives.dart';
import 'package:pandive/features/stats/screens/selection_stats_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'dive_detail_screen.dart';

class DivesTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String query;
  final bool collapseAll;
  const DivesTab({
    super.key,
    required this.db,
    required this.settings,
    this.query = '',
    this.collapseAll = false,
  });
  @override
  State<DivesTab> createState() => _DivesTabState();
}
class _DivesTabState extends State<DivesTab> {
  late List<Dive> _dives = widget.db.listDives(search: widget.query);
  late Set<int> _cave = widget.db.diveIdsWithTag('cave');
  bool _select = false;
  final Set<int> _sel = {};
  @override
  void didUpdateWidget(DivesTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _reload();
  }
  void _reload() => setState(() {
        _dives = widget.db.listDives(search: widget.query);
        _cave = widget.db.diveIdsWithTag('cave');
        _sel.removeWhere((i) => i >= _dives.length);
      });
  void _exitSel() => setState(() {
        _select = false;
        _sel.clear();
      });
  void _toggle(int i) => setState(() {
        if (!_sel.remove(i)) _sel.add(i);
        if (_sel.isEmpty) _select = false;
      });
  void _toggleGroup(List<int> ids) => setState(() {
        _select = true;
        ids.every(_sel.contains) ? _sel.removeAll(ids) : _sel.addAll(ids);
        if (_sel.isEmpty) _select = false;
      });
  void _showStats() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SelectionStatsScreen(dives: [for (final i in _sel) _dives[i]])));
  Future<void> _onOpen(int index) async {
    if (_select) return _toggle(index);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DiveDetailScreen(db: widget.db, dives: _dives, initialIndex: index),
    ));
    _reload();
  }
  Future<void> _deleteSel() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deleteDivesConfirm(_sel.length),
        confirmLabel: t.delete)) return;
    widget.db.deleteDives([for (final i in _sel) _dives[i].id]);
    _exitSel();
    _reload();
  }
  Future<void> _mergeSel() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final gap = widget.settings.mergeGapMinutes;
    final ids = [for (final i in _sel) _dives[i].id];
    if (!await confirmDialog(context, t.mergeConfirm(ids.length),
        confirmLabel: t.merge)) return;
    try {
      widget.db.mergeDives(ids, maxGapMin: gap);
    } on MergeTooFarException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(t.mergeTooFar(e.gapMinutes, gap))));
      return;
    }
    _exitSel();
    _reload();
  }
  Future<void> _adjustTimeSel() async {
    final ok = await adjustDivesTime(
        context, widget.db, [for (final i in _sel) _dives[i]]);
    if (ok) {
      _exitSel();
      _reload();
    }
  }
  Future<void> _add() async {
    await showAddDiveSheet(context, widget.db, widget.settings);
    if (mounted) _reload();
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: _select
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(t.newDive)),
      body: Column(children: [
        if (_select)
          DivesSelectionBar(
            count: _sel.length,
            onClose: _exitSel,
            onStats: _showStats,
            onMerge: _sel.length >= 2 ? _mergeSel : null,
            onAdjustTime: _adjustTimeSel,
            onDelete: _deleteSel,
          ),
        Expanded(
          child: _dives.isEmpty
              ? Center(child: Text(t.noResults))
              : MonthGroupedDives(
                  dives: _dives,
                  settings: widget.settings,
                  caveIds: _cave,
                  onOpen: _onOpen,
                  onLongPress: (i) => setState(() {
                    _select = true;
                    _sel.add(i);
                  }),
                  onToggleGroup: _toggleGroup,
                  selected: _sel,
                  selectionMode: _select,
                  collapseAll: widget.collapseAll,
                ),
        ),
      ]),
    );
  }
}
