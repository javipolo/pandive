/// Dive list with batch selection and all actions (stats,
/// merge, adjust time, export, trip, dive type, tags, delete). Controlled:
/// the parent passes `dives` and reloads in `onChanged` after each mutation.
/// Used in the main tab and in the filtered lists (by site, buddy or tag).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/dives/logic/adjust_time.dart';
import 'package:pandive/features/dives/logic/bulk_edit.dart';
import 'package:pandive/features/dives/logic/export_selection.dart';
import 'package:pandive/features/dives/screens/dive_detail_screen.dart';
import 'package:pandive/features/dives/widgets/dives_selection_bar.dart';
import 'package:pandive/features/dives/widgets/month_grouped_dives.dart';
import 'package:pandive/features/stats/screens/selection_stats_screen.dart';
import 'package:pandive/features/trips/logic/assign_trip_action.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'package:pandive/core/platform.dart';

class DivesActionList extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final List<Dive> dives;
  final Set<int> caveIds;
  final bool collapseAll;
  final int? highlightDiveId; // newly added dive (highlight/scroll to)
  final VoidCallback onChanged; // the parent reloads its list
  final ValueChanged<bool>? onSelectionMode;

  const DivesActionList({
    super.key,
    required this.db,
    required this.settings,
    required this.dives,
    required this.caveIds,
    required this.onChanged,
    this.collapseAll = false,
    this.highlightDiveId,
    this.onSelectionMode,
  });

  @override
  State<DivesActionList> createState() => _DivesActionListState();
}

class _DivesActionListState extends State<DivesActionList> {
  bool _select = false;
  final Set<int> _sel = {};

  void _setSelect(bool v) {
    if (_select == v) return;
    _select = v;
    widget.onSelectionMode?.call(v);
  }

  void _exitSel() => setState(() {
        _setSelect(false);
        _sel.clear();
      });

  void _toggle(int i) => setState(() {
        if (!_sel.remove(i)) _sel.add(i);
        if (_sel.isEmpty) _setSelect(false);
      });

  void _toggleGroup(List<int> ids) => setState(() {
        _setSelect(true);
        ids.every(_sel.contains) ? _sel.removeAll(ids) : _sel.addAll(ids);
        if (_sel.isEmpty) _setSelect(false);
      });

  List<Dive> get _picked => [for (final i in _sel) widget.dives[i]];

  bool get _allSelected =>
      widget.dives.isNotEmpty && _sel.length == widget.dives.length;

  void _toggleSelectAll() => setState(() {
        if (_allSelected) {
          _sel.clear();
          _setSelect(false);
        } else {
          _setSelect(true);
          _sel.addAll([for (var i = 0; i < widget.dives.length; i++) i]);
        }
      });

  void _showStats() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SelectionStatsScreen(db: widget.db, dives: _picked)));

  Future<void> _onOpen(int index) async {
    if (_select) return _toggle(index);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DiveDetailScreen(
          db: widget.db, dives: widget.dives, initialIndex: index),
    ));
    widget.onChanged();
  }

  Future<void> _deleteSel() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deleteDivesConfirm(_sel.length),
        confirmLabel: t.delete)) {
      return;
    }
    widget.db.deleteDives([for (final d in _picked) d.id]);
    widget.db.autoRenumber();
    _exitSel();
    widget.onChanged();
  }

  Future<void> _mergeSel() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final gap = widget.settings.mergeGapMinutes;
    final ids = [for (final d in _picked) d.id];
    if (!await confirmDialog(context, t.mergeConfirm(ids.length),
        confirmLabel: t.merge)) {
      return;
    }
    try {
      widget.db.mergeDives(ids, maxGapMin: gap);
      widget.db.autoRenumber();
    } on MergeTooFarException catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(t.mergeTooFar(e.gapMinutes, gap))));
      return;
    }
    _exitSel();
    widget.onChanged();
  }

  Future<void> _adjustTimeSel() async {
    if (await adjustDivesTime(context, widget.db, _picked)) {
      _exitSel();
      widget.onChanged();
    }
  }

  Future<void> _exportSel() async {
    await exportSelectionDdb(context, widget.db, _picked);
    _exitSel();
  }

  List<int> get _pickedIds => [for (final d in _picked) d.id];

  Future<void> _assignTripSel() async {
    if (await runAssignToTrip(context, widget.db, _pickedIds)) {
      _exitSel();
      widget.onChanged();
    }
  }

  /// Batch edits (dive type, tags). The selection is index-based and the
  /// reload may drop dives from a filtered list (e.g. removing the tag it
  /// filters by), so it's cleared like after the other mutations.
  Future<void> _bulk(
      Future<bool> Function(BuildContext, DivemateDb, List<int>) run) async {
    if (await run(context, widget.db, _pickedIds)) {
      _exitSel();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      if (_select)
        DivesSelectionBar(
            count: _sel.length,
            onClose: _exitSel,
            onStats: _showStats,
            onMerge: _sel.length >= 2 ? _mergeSel : null,
            onAdjustTime: _adjustTimeSel,
            onExport: isWeb ? null : _exportSel,
            onAssignTrip: _assignTripSel,
            onDiveType: () => _bulk(runBulkDiveType),
            onAddTag: () => _bulk(runBulkAddTag),
            onRemoveTag: () => _bulk(runBulkRemoveTag),
            onDelete: _deleteSel,
            onSelectAll: _toggleSelectAll,
            allSelected: _allSelected),
      Expanded(
        child: widget.dives.isEmpty
            ? Center(child: Text(t.noResults))
            : MonthGroupedDives(
                dives: widget.dives,
                settings: widget.settings,
                caveIds: widget.caveIds,
                highlightDiveId: widget.highlightDiveId,
                onOpen: _onOpen,
                onLongPress: (i) => setState(() {
                  _setSelect(true);
                  _sel.add(i);
                }),
                onToggleGroup: _toggleGroup,
                selected: _sel,
                selectionMode: _select,
                collapseAll: widget.collapseAll),
      ),
    ]);
  }
}
