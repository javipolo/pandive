/// Vista de estadísticas en secciones (como el detalle de buceo) + barras por
/// periodo. Reutilizada por la pestaña global y por las stats de una selección.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/widgets/dive_detail_fields.dart';
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

  String _u(double? v, String unit, {int dec = 1}) =>
      v == null ? '—' : '${v.toStringAsFixed(dec)} $unit';
  String _min(double? v) => v == null ? '—' : '${v.round()} min';

  String _totalLong(double m) {
    final tot = m.round();
    return '${tot ~/ 1440}d ${(tot % 1440) ~/ 60}h ${tot % 60}m';
  }

  String _totalShort(double m) {
    final tot = m.round();
    return '${tot ~/ 60}h ${tot % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fullFmt = DateFormat.yMMMMd(lang);
    final s = widget.stats;
    LabeledValue date(String label, DateTime? d) =>
        LabeledValue(label, d == null ? null : fullFmt.format(d));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        twoCol(
          LabeledValue(t.statsDives, '${s.totalDives}'),
          s.buddiesCount == null
              ? null
              : LabeledValue(t.buddies, '${s.buddiesCount}'),
        ),
        sectionLine(),
        twoCol(date(t.statsFirst, s.firstDive), date(t.statsLast, s.lastDive)),
        twoCol(
          LabeledValue(t.statsTotalTime, _totalLong(s.totalMinutes)),
          LabeledValue(t.statsTotalHours, _totalShort(s.totalMinutes)),
        ),
        twoCol(
          LabeledValue(t.statsMaxDive, _min(s.maxDiveMinutes)),
          LabeledValue(t.statsAvgDive, _min(s.avgDiveMinutes)),
        ),
        sectionLine(),
        twoCol(
          LabeledValue(t.statMaxDepth, _u(s.maxDepth, 'm')),
          LabeledValue(t.statAvgDepth, _u(s.avgDepth, 'm')),
        ),
        if (s.sacAvg != null) ...[
          sectionLine(),
          threeCol(
            LabeledValue(t.statsSacMax, _u(s.sacMax, 'l/min')),
            LabeledValue(t.statsSacMin, _u(s.sacMin, 'l/min')),
            LabeledValue(t.statsSacAvg, _u(s.sacAvg, 'l/min')),
          ),
        ],
        sectionLine(),
        threeCol(
          LabeledValue(t.statsTempMax, _u(s.tempMax, '°C')),
          LabeledValue(t.statsTempMin, _u(s.tempMin, '°C')),
          LabeledValue(t.statsAvgTemp, _u(s.avgWaterTemp, '°C')),
        ),
        if (widget.dates.isNotEmpty) ...[
          sectionLine(),
          SegmentedButton<StatsPeriod>(
            segments: [
              ButtonSegment(value: StatsPeriod.year, label: Text(t.byYear)),
              ButtonSegment(value: StatsPeriod.month, label: Text(t.byMonth)),
              ButtonSegment(value: StatsPeriod.week, label: Text(t.byWeek)),
            ],
            selected: {_period},
            onSelectionChanged: (sel) => setState(() => _period = sel.first),
          ),
          const SizedBox(height: 12),
          PeriodBars(data: bucketByPeriod(widget.dates, _period)),
        ],
      ],
    );
  }
}
