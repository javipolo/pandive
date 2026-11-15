/// Vista de estadísticas: tarjetas + barras por periodo (año/mes/semana), con
/// selector. Reutilizada por la pestaña global y por las stats de una selección.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/stat_card.dart';
import 'package:pandive/features/stats/widgets/stats_buckets.dart';
import 'package:pandive/features/stats/widgets/year_bars.dart';
import 'package:pandive/l10n/app_localizations.dart';

class StatsView extends StatefulWidget {
  final LogbookStats stats;
  final List<DateTime> dates;
  const StatsView({super.key, required this.stats, required this.dates});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  StatsPeriod _period = StatsPeriod.year;

  List<Widget> _cards(AppLocalizations t, DateFormat fmt) {
    final s = widget.stats;
    return [
      StatCard(label: t.statsDives, value: '${s.totalDives}'),
      StatCard(
          label: t.statsTotalTime,
          value: '${s.totalHours.toStringAsFixed(0)} h'),
      if (s.avgDiveMinutes != null)
        StatCard(
            label: t.statsAvgDive, value: '${s.avgDiveMinutes!.round()} min'),
      if (s.maxDepth != null)
        StatCard(
            label: t.statMaxDepth, value: '${s.maxDepth!.toStringAsFixed(1)} m'),
      if (s.avgDepth != null)
        StatCard(
            label: t.statAvgDepth, value: '${s.avgDepth!.toStringAsFixed(1)} m'),
      if (s.avgWaterTemp != null)
        StatCard(
            label: t.statsAvgTemp,
            value: '${s.avgWaterTemp!.toStringAsFixed(1)} °C'),
      if (s.firstDive != null)
        StatCard(label: t.statsFirst, value: fmt.format(s.firstDive!)),
      if (s.lastDive != null)
        StatCard(label: t.statsLast, value: fmt.format(s.lastDive!)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt =
        DateFormat('MMM yyyy', Localizations.localeOf(context).languageCode);
    final bars = bucketByPeriod(widget.dates, _period);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: _cards(t, fmt)),
        if (widget.dates.isNotEmpty) ...[
          const SizedBox(height: 24),
          SegmentedButton<StatsPeriod>(
            segments: [
              ButtonSegment(value: StatsPeriod.year, label: Text(t.byYear)),
              ButtonSegment(value: StatsPeriod.month, label: Text(t.byMonth)),
              ButtonSegment(value: StatsPeriod.week, label: Text(t.byWeek)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 12),
          PeriodBars(data: bars),
        ],
      ],
    );
  }
}
