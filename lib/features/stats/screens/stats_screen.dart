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

  @override
  void initState() {
    super.initState();
    _stats = widget.db.computeStats();
  }

  @override
  Widget build(BuildContext context) => StatsView(stats: _stats);
}
