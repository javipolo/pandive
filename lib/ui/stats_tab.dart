/// Pestaña de estadísticas agregadas del logbook.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/divemate_db.dart';
import '../models.dart';

class StatsTab extends StatefulWidget {
  final DivemateDb db;
  const StatsTab({super.key, required this.db});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  late LogbookStats _stats;
  final _dateFmt = DateFormat('MMM yyyy', 'es');

  @override
  void initState() {
    super.initState();
    _stats = widget.db.computeStats();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final cards = <Widget>[
      _StatCard(label: 'Inmersiones', value: '${s.totalDives}'),
      _StatCard(
          label: 'Tiempo total',
          value: '${s.totalHours.toStringAsFixed(0)} h'),
      if (s.avgDiveMinutes != null)
        _StatCard(
            label: 'Media inmersión',
            value: '${s.avgDiveMinutes!.round()} min'),
      if (s.maxDepth != null)
        _StatCard(
            label: 'Prof. máxima',
            value: '${s.maxDepth!.toStringAsFixed(1)} m'),
      if (s.avgDepth != null)
        _StatCard(
            label: 'Prof. media',
            value: '${s.avgDepth!.toStringAsFixed(1)} m'),
      if (s.avgWaterTemp != null)
        _StatCard(
            label: 'Temp. media',
            value: '${s.avgWaterTemp!.toStringAsFixed(1)} °C'),
      if (s.firstDive != null)
        _StatCard(label: 'Primera', value: _dateFmt.format(s.firstDive!)),
      if (s.lastDive != null)
        _StatCard(label: 'Última', value: _dateFmt.format(s.lastDive!)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: cards),
        if (s.divesPerYear.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Por año', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _YearBars(data: s.divesPerYear),
        ],
      ],
    );
  }
}

class _YearBars extends StatelessWidget {
  final Map<int, int> data;
  const _YearBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final years = data.keys.toList()..sort();
    final maxCount = data.values.fold<int>(1, (m, v) => v > m ? v : m);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final y in years)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('$y',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth * (data[y]! / maxCount);
                      return Stack(
                        children: [
                          Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Container(
                            height: 22,
                            width: w.clamp(2, c.maxWidth),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${data[y]}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}
