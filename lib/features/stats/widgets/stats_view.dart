/// Statistics view in sections (like the dive detail) + bars per
/// period. Reused by the global tab and by the stats of a selection.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/widgets/dive_detail_fields.dart';
import 'package:pandive/features/stats/widgets/records_card.dart';
import 'package:pandive/features/stats/widgets/stats_buckets.dart';
import 'package:pandive/features/stats/widgets/year_bars.dart';
import 'package:pandive/l10n/app_localizations.dart';

class StatsView extends StatefulWidget {
  final LogbookStats stats;
  final List<DateTime> dates;
  final PersonalRecords? records; // global only: records card (tappable)
  final void Function(int diveId)? onOpenRecord;
  const StatsView(
      {super.key,
      required this.stats,
      required this.dates,
      this.records,
      this.onOpenRecord});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  late StatsPeriod _period = _initialPeriod();

  // Initial span by date range: >=13 months year, 3-12 months month,
  // <3 months week. The user can change it later.
  StatsPeriod _initialPeriod() {
    if (widget.dates.isEmpty) return StatsPeriod.year;
    final sorted = [...widget.dates]..sort();
    final days = sorted.last.difference(sorted.first).inDays;
    if (days >= 395) return StatsPeriod.year; // ~13 meses
    if (days >= 91) return StatsPeriod.month; // ~3 meses
    return StatsPeriod.week;
  }

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
    final fullFmt = DateFormat('dd/MM/yyyy');
    final s = widget.stats;
    LabeledValue date(String label, DateTime? d) =>
        LabeledValue(label, d == null ? null : fullFmt.format(d));
    final records = widget.records;
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
        if ((s.decoDives ?? 0) > 0) ...[
          sectionLine(),
          twoCol(
            LabeledValue(t.statsDecoDives, '${s.decoDives}'),
            LabeledValue(t.statsMaxTts, _min(s.maxTts?.toDouble())),
          ),
          twoCol(
            LabeledValue(t.statsMaxCeiling, _u(s.maxCeiling, 'm')),
            LabeledValue(t.statsMaxCeilingTime, _min(s.maxCeilingMinutes)),
          ),
        ],
        if (records != null &&
            !records.isEmpty &&
            widget.onOpenRecord != null) ...[
          sectionLine(),
          Text(t.recordsTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          RecordsCard(
              records: records,
              totalDives: s.totalDives,
              onOpen: widget.onOpenRecord!),
        ],
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
