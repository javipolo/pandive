/// Lista de inmersiones agrupada por año y, dentro, por mes. Cabeceras
/// colapsables y seleccionables en lote (año entero o mes). "Colapsar todo"
/// (barra superior) colapsa los años.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/widgets/dive_group_header.dart';
import 'package:pandive/features/dives/widgets/dive_row.dart';

class MonthGroupedDives extends StatefulWidget {
  final List<Dive> dives;
  final Settings settings;
  final Set<int> caveIds;
  final void Function(int index) onOpen;
  final void Function(int index)? onLongPress;
  final void Function(List<int> indices)? onToggleGroup;
  final Set<int> selected;
  final bool selectionMode;
  final bool collapseAll;
  const MonthGroupedDives({
    super.key,
    required this.dives,
    required this.settings,
    this.caveIds = const {},
    required this.onOpen,
    this.onLongPress,
    this.onToggleGroup,
    this.selected = const {},
    this.selectionMode = false,
    this.collapseAll = false,
  });

  @override
  State<MonthGroupedDives> createState() => _MonthGroupedDivesState();
}

class _MonthGroupedDivesState extends State<MonthGroupedDives> {
  final Set<String> _collapsed = {};

  String _yKey(Dive d) => d.date == null ? 'Y:—' : 'Y:${d.date!.year}';
  String _mKey(Dive d) => d.date == null
      ? 'M:—'
      : 'M:${d.date!.year}-${d.date!.month.toString().padLeft(2, '0')}';

  @override
  void didUpdateWidget(MonthGroupedDives old) {
    super.didUpdateWidget(old);
    if (old.collapseAll != widget.collapseAll) {
      _collapsed.clear();
      if (widget.collapseAll) {
        // Colapsar todo = años y meses.
        _collapsed
          ..addAll(widget.dives.map(_yKey))
          ..addAll(widget.dives.map(_mKey));
      }
    }
  }

  void _toggle(String k) =>
      setState(() => _collapsed.contains(k) ? _collapsed.remove(k) : _collapsed.add(k));

  // Colapsar un año colapsa también sus meses; expandirlo solo muestra el año.
  void _toggleYear(String yk, List<String> months) => setState(() {
        if (_collapsed.contains(yk)) {
          _collapsed.remove(yk);
        } else {
          _collapsed
            ..add(yk)
            ..addAll(months);
        }
      });

  bool get _groupSel => widget.selectionMode && widget.onToggleGroup != null;

  @override
  Widget build(BuildContext context) {
    final yearKeys = <String>[];
    final yearMonths = <String, List<String>>{};
    final monthIdx = <String, List<int>>{};
    final yearIdx = <String, List<int>>{};
    for (var i = 0; i < widget.dives.length; i++) {
      final d = widget.dives[i];
      final yk = _yKey(d), mk = _mKey(d);
      if (!yearMonths.containsKey(yk)) {
        yearKeys.add(yk);
        yearMonths[yk] = [];
        yearIdx[yk] = [];
      }
      yearIdx[yk]!.add(i);
      if (!monthIdx.containsKey(mk)) {
        yearMonths[yk]!.add(mk);
        monthIdx[mk] = [];
      }
      monthIdx[mk]!.add(i);
    }

    final monthFmt =
        DateFormat('MMMM', Localizations.localeOf(context).languageCode);
    final rows = <Widget>[];
    for (final yk in yearKeys) {
      final yIdxs = yearIdx[yk]!;
      final yCollapsed = _collapsed.contains(yk);
      rows.add(_header(yk == 'Y:—' ? '—' : yk.substring(2), yIdxs, yCollapsed,
          true, () => _toggleYear(yk, yearMonths[yk]!)));
      if (yCollapsed) continue;
      for (final mk in yearMonths[yk]!) {
        final mIdxs = monthIdx[mk]!;
        final mCollapsed = _collapsed.contains(mk);
        final label =
            mk == 'M:—' ? '—' : monthFmt.format(widget.dives[mIdxs.first].date!);
        rows.add(_header(label, mIdxs, mCollapsed, false, () => _toggle(mk)));
        if (mCollapsed) continue;
        for (final i in mIdxs) {
          rows.add(DiveRow(
            dive: widget.dives[i],
            settings: widget.settings,
            isCave: widget.caveIds.contains(widget.dives[i].id),
            selected: widget.selected.contains(i),
            onTap: () => widget.onOpen(i),
            onLongPress:
                widget.onLongPress == null ? null : () => widget.onLongPress!(i),
          ));
        }
      }
    }
    return ListView(children: rows);
  }

  Widget _header(String label, List<int> idxs, bool collapsed, bool isYear,
      VoidCallback onCollapse) {
    final allSel = idxs.every(widget.selected.contains);
    return DiveGroupHeader(
      label: label,
      count: idxs.length,
      collapsed: collapsed,
      isYear: isYear,
      selectedGroup: _groupSel && allSel,
      onTap: _groupSel ? () => widget.onToggleGroup!(idxs) : onCollapse,
      onLongPress:
          widget.onToggleGroup == null ? null : () => widget.onToggleGroup!(idxs),
    );
  }
}
