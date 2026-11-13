/// Lista de inmersiones agrupada por mes, con cabeceras colapsables y
/// colapsar/expandir todo.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class MonthGroupedDives extends StatefulWidget {
  final List<Dive> dives;
  final void Function(int index) onOpen;
  const MonthGroupedDives({super.key, required this.dives, required this.onOpen});

  @override
  State<MonthGroupedDives> createState() => _MonthGroupedDivesState();
}

class _MonthGroupedDivesState extends State<MonthGroupedDives> {
  final Set<String> _collapsed = {};

  String _key(Dive d) => d.date == null
      ? '—'
      : '${d.date!.year}-${d.date!.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final monthFmt = DateFormat('MMMM yyyy', locale);
    final dateFmt = DateFormat('d MMM yyyy', locale);

    // Grupos en orden de aparición (la lista ya viene ordenada desc).
    final keys = <String>[];
    final groups = <String, List<int>>{}; // key -> índices en widget.dives
    for (var i = 0; i < widget.dives.length; i++) {
      final k = _key(widget.dives[i]);
      (groups[k] ??= (keys..add(k), <int>[]).$2).add(i);
    }

    final allCollapsed = keys.isNotEmpty && _collapsed.length == keys.length;
    final rows = <Widget>[
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: '',
          icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
          onPressed: () => setState(() {
            if (allCollapsed) {
              _collapsed.clear();
            } else {
              _collapsed.addAll(keys);
            }
          }),
        ),
      ),
    ];
    for (final k in keys) {
      final idxs = groups[k]!;
      final label = k == '—'
          ? '—'
          : monthFmt.format(widget.dives[idxs.first].date!);
      final collapsed = _collapsed.contains(k);
      rows.add(_header(context, label, idxs.length, collapsed, () {
        setState(() =>
            collapsed ? _collapsed.remove(k) : _collapsed.add(k));
      }));
      if (!collapsed) {
        for (final i in idxs) {
          rows.add(_tile(context, widget.dives[i], i, dateFmt));
        }
      }
    }
    return ListView(children: rows);
  }

  Widget _header(BuildContext context, String label, int count, bool collapsed,
      VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: ListTile(
        dense: true,
        title: Text('$label  ($count)',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
        trailing: Icon(collapsed ? Icons.expand_more : Icons.expand_less,
            color: cs.onPrimaryContainer),
        onTap: onTap,
      ),
    );
  }

  Widget _tile(BuildContext context, Dive d, int index, DateFormat dateFmt) {
    final subtitle =
        [d.place, d.country].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
    final stats = [
      if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
      if (d.durationMin != null) '${d.durationMin!.round()} min',
      if (d.waterTemp != null) '${d.waterTemp!.toStringAsFixed(0)} °C',
    ].join('   ');
    return ListTile(
      leading: CircleAvatar(child: Text(d.number?.toString() ?? '—')),
      title: Text(subtitle.isEmpty ? AppLocalizations.of(context).dive : subtitle,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.date != null) Text(dateFmt.format(d.date!)),
          if (stats.isNotEmpty)
            Text(stats, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: d.date != null && stats.isNotEmpty,
      onTap: () => widget.onOpen(index),
    );
  }
}
