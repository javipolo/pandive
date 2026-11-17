/// Lista de buceos agrupados por mes con casillas de selección explícitas
/// (casilla por mes tristate + casilla por buceo). Para "Rellenar desde .ddb".
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/settings/logic/enrich_logbook.dart';

class FillDiveChecklist extends StatelessWidget {
  final List<Dive> dives;
  final Map<int, DiveMatch> matches;
  final Set<int> selected; // índices en [dives]
  final void Function(int index) onToggle;
  final void Function(List<int> indices) onToggleGroup;
  const FillDiveChecklist({
    super.key,
    required this.dives,
    required this.matches,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final monthFmt = DateFormat('MMMM', locale);
    final dayFmt = DateFormat('dd/MM/yyyy', locale);
    // Agrupa por año y, dentro, por mes, preservando el orden de [dives].
    final yearIdx = <String, List<int>>{};
    final yearMonths = <String, List<String>>{};
    final monthIdx = <String, List<int>>{};
    final monthLabel = <String, String>{};
    for (var i = 0; i < dives.length; i++) {
      final d = dives[i].date;
      final yk = d == null ? '—' : '${d.year}';
      final mk = d == null ? '—' : '${d.year}-${d.month}';
      yearIdx.putIfAbsent(yk, () => []).add(i);
      if (!monthIdx.containsKey(mk)) {
        yearMonths.putIfAbsent(yk, () => []).add(mk);
        monthLabel[mk] = d == null ? '—' : monthFmt.format(d);
      }
      monthIdx.putIfAbsent(mk, () => []).add(i);
    }

    Widget header(List<int> idx, String label, {required bool year}) {
      final all = idx.every(selected.contains);
      return CheckboxListTile(
        dense: !year,
        tileColor: year ? cs.primaryContainer : cs.surfaceContainerHighest,
        contentPadding: EdgeInsets.only(left: year ? 16 : 32, right: 16),
        value: all ? true : (idx.any(selected.contains) ? null : false),
        tristate: true,
        onChanged: (_) => onToggleGroup(idx),
        title: Text(label.toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: year ? 16 : 14)),
      );
    }

    final rows = <Widget>[];
    for (final yk in yearIdx.keys) {
      rows.add(header(yearIdx[yk]!, yk, year: true));
      for (final mk in yearMonths[yk]!) {
        rows.add(header(monthIdx[mk]!, monthLabel[mk]!, year: false));
        for (final i in monthIdx[mk]!) {
          final d = dives[i];
          rows.add(CheckboxListTile(
            value: selected.contains(i),
            onChanged: (_) => onToggle(i),
            title: Text(d.date != null ? dayFmt.format(d.date!) : '—'),
            subtitle: Text('→ ${matches[d.id]?.place ?? ''}'),
          ));
        }
      }
    }
    return ListView(children: rows);
  }
}
