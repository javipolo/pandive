/// Estadísticas calculadas solo sobre una selección de inmersiones.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/stats/widgets/stats_view.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SelectionStatsScreen extends StatelessWidget {
  final List<Dive> dives;
  const SelectionStatsScreen({super.key, required this.dives});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.statsSelectedTitle)),
      body: StatsView(
        stats: LogbookStats.fromDives(dives),
        dates: [for (final d in dives) if (d.date != null) d.date!],
      ),
    );
  }
}
