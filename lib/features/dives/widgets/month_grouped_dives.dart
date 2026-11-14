/// Lista de inmersiones agrupada por mes, con cabeceras colapsables.
/// El colapsar/expandir todo lo controla la barra superior (collapseAll).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/widgets/dive_row.dart';

class MonthGroupedDives extends StatefulWidget {
  final List<Dive> dives;
  final Settings settings;
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

  String _key(Dive d) => d.date == null
      ? '—'
      : '${d.date!.year}-${d.date!.month.toString().padLeft(2, '0')}';

  @override
  void didUpdateWidget(MonthGroupedDives old) {
    super.didUpdateWidget(old);
    if (old.collapseAll != widget.collapseAll) {
      _collapsed
        ..clear()
        ..addAll(widget.collapseAll ? widget.dives.map(_key) : const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthFmt =
        DateFormat('MMMM yyyy', Localizations.localeOf(context).languageCode);
    final keys = <String>[];
    final groups = <String, List<int>>{};
    for (var i = 0; i < widget.dives.length; i++) {
      final k = _key(widget.dives[i]);
      (groups[k] ??= (keys..add(k), <int>[]).$2).add(i);
    }

    final rows = <Widget>[];
    for (final k in keys) {
      final idxs = groups[k]!;
      final label =
          k == '—' ? '—' : monthFmt.format(widget.dives[idxs.first].date!);
      final collapsed = _collapsed.contains(k);
      void toggleCollapse() => setState(
          () => collapsed ? _collapsed.remove(k) : _collapsed.add(k));
      final groupSel = widget.selectionMode && widget.onToggleGroup != null;
      final allSel = idxs.every(widget.selected.contains);
      rows.add(_header(
        context,
        label,
        idxs.length,
        collapsed,
        groupSel ? () => widget.onToggleGroup!(idxs) : toggleCollapse,
        onLongPress: widget.onToggleGroup == null
            ? null
            : () => widget.onToggleGroup!(idxs),
        selectedGroup: groupSel && allSel,
      ));
      if (!collapsed) {
        for (final i in idxs) {
          rows.add(DiveRow(
            dive: widget.dives[i],
            settings: widget.settings,
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

  Widget _header(BuildContext context, String label, int count, bool collapsed,
      VoidCallback onTap,
      {VoidCallback? onLongPress, bool selectedGroup = false}) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selectedGroup ? cs.primary : cs.primaryContainer,
      child: ListTile(
        dense: true,
        leading: selectedGroup
            ? Icon(Icons.check_circle, color: cs.onPrimary)
            : null,
        title: Text('${label.toUpperCase()}  ($count)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: selectedGroup ? cs.onPrimary : cs.onPrimaryContainer)),
        trailing: Icon(collapsed ? Icons.expand_more : Icons.expand_less,
            color: selectedGroup ? cs.onPrimary : cs.onPrimaryContainer),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
