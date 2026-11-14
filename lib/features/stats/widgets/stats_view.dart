/// Vista de estadísticas (tarjetas + barras por año) a partir de un LogbookStats.
/// Reutilizada por la pestaña global y por las stats de una selección.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/stat_card.dart';
import 'package:pandive/features/stats/widgets/year_bars.dart';
import 'package:pandive/l10n/app_localizations.dart';

class StatsView extends StatelessWidget {
  final LogbookStats stats;
  const StatsView({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dateFmt =
        DateFormat('MMM yyyy', Localizations.localeOf(context).languageCode);
    final s = stats;
    final cards = <Widget>[
      StatCard(label: t.statsDives, value: '${s.totalDives}'),
      StatCard(
          label: t.statsTotalTime,
          value: '${s.totalHours.toStringAsFixed(0)} h'),
      if (s.avgDiveMinutes != null)
        StatCard(
            label: t.statsAvgDive, value: '${s.avgDiveMinutes!.round()} min'),
      if (s.maxDepth != null)
        StatCard(
            label: t.statMaxDepth,
            value: '${s.maxDepth!.toStringAsFixed(1)} m'),
      if (s.avgDepth != null)
        StatCard(
            label: t.statAvgDepth,
            value: '${s.avgDepth!.toStringAsFixed(1)} m'),
      if (s.avgWaterTemp != null)
        StatCard(
            label: t.statsAvgTemp,
            value: '${s.avgWaterTemp!.toStringAsFixed(1)} °C'),
      if (s.firstDive != null)
        StatCard(label: t.statsFirst, value: dateFmt.format(s.firstDive!)),
      if (s.lastDive != null)
        StatCard(label: t.statsLast, value: dateFmt.format(s.lastDive!)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: cards),
        if (s.divesPerYear.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.perYear, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          YearBars(data: s.divesPerYear),
        ],
      ],
    );
  }
}
