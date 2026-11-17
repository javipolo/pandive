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
    final locale = Localizations.localeOf(context).languageCode;
    final monthFmt = DateFormat('MMMM yyyy', locale);
    final dayFmt = DateFormat('dd/MM/yyyy', locale);
    // Agrupa índices por mes, preservando el orden de [dives].
    final groups = <String, List<int>>{};
    final labels = <String, String>{};
    for (var i = 0; i < dives.length; i++) {
      final d = dives[i].date;
      final key = d == null ? '—' : '${d.year}-${d.month}';
      (groups[key] ??= []).add(i);
      labels[key] = d == null ? '—' : monthFmt.format(d);
    }

    final rows = <Widget>[];
    for (final entry in groups.entries) {
      final idx = entry.value;
      final all = idx.every(selected.contains);
      final some = idx.any(selected.contains);
      rows.add(CheckboxListTile(
        dense: true,
        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        value: all ? true : (some ? null : false),
        tristate: true,
        onChanged: (_) => onToggleGroup(idx),
        title: Text(labels[entry.key]!.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ));
      for (final i in idx) {
        final d = dives[i];
        rows.add(CheckboxListTile(
          value: selected.contains(i),
          onChanged: (_) => onToggle(i),
          title: Text(d.date != null ? dayFmt.format(d.date!) : '—'),
          subtitle: Text('→ ${matches[d.id]?.place ?? ''}'),
        ));
      }
    }
    return ListView(children: rows);
  }
}
