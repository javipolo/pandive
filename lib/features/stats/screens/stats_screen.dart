/// Pestaña de estadísticas agregadas del logbook.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/stats/widgets/stats_view.dart';

class StatsTab extends StatefulWidget {
  final DivemateDb db;
  const StatsTab({super.key, required this.db});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  late LogbookStats _stats;
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _stats = widget.db.computeStats();
    _dates = [
      for (final d in widget.db.listDives())
        if (d.date != null) d.date!,
    ];
  }

  @override
  Widget build(BuildContext context) =>
      StatsView(stats: _stats, dates: _dates);
}
