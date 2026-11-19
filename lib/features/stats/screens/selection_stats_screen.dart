/// Estadísticas calculadas solo sobre una selección de inmersiones.
/// Usa la misma plantilla y cálculos que las stats globales (computeStats).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/plan/screens/plan_dive_screen.dart';
import 'package:pandive/features/stats/widgets/stats_view.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SelectionStatsScreen extends StatelessWidget {
  final DivemateDb db;
  final List<Dive> dives;
  const SelectionStatsScreen({super.key, required this.db, required this.dives});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stats = db.computeStats(ids: [for (final d in dives) d.id]);
    final isCave = dives.any((d) => db
        .tagsForDive(d.id)
        .any((tag) => tag.name.toLowerCase().contains('cave') ||
            tag.name.toLowerCase().contains('cueva')));
    final rule = isCave ? ReserveRule.thirds : ReserveRule.bar35;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.statsSelectedTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: t.planTitle,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlanDiveScreen(
                db: db,
                rmv: stats.sacAvg,
                avgDepth: stats.avgDepth,
                avgTime: stats.avgDiveMinutes,
                initialRule: rule,
              ),
            )),
          ),
        ],
      ),
      body: StatsView(
        stats: stats,
        dates: [for (final d in dives) if (d.date != null) d.date!],
      ),
    );
  }
}
