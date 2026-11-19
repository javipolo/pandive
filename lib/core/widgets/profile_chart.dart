/// Perfil de inmersión: profundidad (azul, superficie arriba) + temperatura
/// (roja, eje derecho). Al tocar: línea vertical a toda altura + valores.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart_axes.dart';
import 'package:pandive/features/dives/widgets/gas_segments.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ProfileChart extends StatefulWidget {
  final DiveProfile profile;
  final bool compact; // oculta los títulos de los ejes (gráfica pequeña)
  final List<GasChange> gasChanges; // marcas de cambio de gas (ampliada)
  const ProfileChart(
      {super.key,
      required this.profile,
      this.compact = false,
      this.gasChanges = const []});
  @override
  State<ProfileChart> createState() => _ProfileChartState();
}
const _hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
class _ProfileChartState extends State<ProfileChart> {
  int? _idx;
  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final t = AppLocalizations.of(context);
    if (profile.isEmpty) return Center(child: Text(t.noProfile));
    final cs = Theme.of(context).colorScheme;
    final times = profile.timesMinutes;
    final depths = profile.depths;
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    final maxTime = times.isNotEmpty ? times.last : 1.0;
    final depthStep = niceStep(maxDepth, 5);
    final minY = -(((maxDepth / depthStep).ceil()) * depthStep).toDouble();
    const maxY = 0.0;
    final prefix = <double>[];
    var acc = 0.0;
    for (final d in depths) {
      acc += d;
      prefix.add(acc);
    }
    final depthSpots = [
      for (var i = 0; i < depths.length; i++) FlSpot(times[i], -depths[i]),
    ];
    final hasTemp = profile.hasTemp;
    var tLo = 0.0, tHi = 5.0;
    List<FlSpot> tempSpots = [];
    if (hasTemp) {
      final ts = profile.temps.whereType<double>();
      tLo = ts.reduce((a, b) => a < b ? a : b).floorToDouble();
      tHi = ts.reduce((a, b) => a > b ? a : b).ceilToDouble();
      if (tHi - tLo < 5) {
        tLo = ((tHi + tLo) / 2 - 2.5).floorToDouble();
        tHi = tLo + 5;
      }
      final pad = ((tHi - tLo) / 5).ceil().toDouble();
      tLo -= pad;
      tHi += pad;
      double tempY(double v) => minY + (v - tLo) / (tHi - tLo) * (maxY - minY);
      tempSpots = [
        for (var i = 0; i < profile.temps.length; i++)
          if (profile.temps[i] != null)
            FlSpot(times[i], tempY(profile.temps[i]!)),
      ];
    }
    return LineChart(LineChartData(
      minX: 0,
      maxX: maxTime,
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.all(),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: profileTooltip(times, depths, prefix, profile.temps,
            ceiling: profile.ceiling, ndl: profile.ndl, tts: profile.tts,
            extra: profile),
        touchCallback: (event, resp) {
          final spots = resp?.lineBarSpots;
          if (!event.isInterestedForInteractions || spots == null || spots.isEmpty) {
            if (_idx != null) setState(() => _idx = null);
            return;
          }
          final i = spots.first.spotIndex;
          if (i != _idx) setState(() => _idx = i);
        },
      ),
      extraLinesData: ExtraLinesData(verticalLines: [
        ...gasVerticalLines(widget.gasChanges),
        if (_idx != null && _idx! < times.length)
          VerticalLine(x: times[_idx!], color: cs.primary, strokeWidth: 2),
      ]),
      gridData: FlGridData(
        show: true,
        horizontalInterval: depthStep,
        verticalInterval: niceStep(maxTime, 6),
        getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
        getDrawingVerticalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: _hidden,
        leftTitles: widget.compact ? _hidden : depthAxis(context, t, depthStep),
        rightTitles: (hasTemp && !widget.compact)
            ? tempAxis(minY, tLo, tHi)
            : _hidden,
        bottomTitles: widget.compact ? _hidden : timeAxis(context, t, maxTime),
      ),
      borderData:
          FlBorderData(show: true, border: Border.all(color: cs.outlineVariant)),
      lineBarsData: [
        LineChartBarData(
          spots: depthSpots,
          isCurved: false,
          color: cs.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          aboveBarData:
              BarAreaData(show: true, color: cs.primary.withValues(alpha: 0.28)),
        ),
        if (hasTemp)
          LineChartBarData(
            spots: tempSpots,
            isCurved: false,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        // Banda de techo de deco: relleno rojo desde la superficie hasta el techo.
        if (profile.hasDeco)
          LineChartBarData(
            spots: [
              for (var i = 0; i < profile.ceiling.length; i++)
                FlSpot(times[i], -profile.ceiling[i]),
            ],
            isCurved: false,
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
            aboveBarData:
                BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.30)),
          ),
      ],
    ));
  }
}
