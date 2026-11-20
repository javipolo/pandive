/// Pestaña de estadísticas agregadas del logbook.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/screens/dive_detail_screen.dart';
import 'package:pandive/features/stats/widgets/stats_view.dart';

class StatsTab extends StatefulWidget {
  final DivemateDb db;
  const StatsTab({super.key, required this.db});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  late LogbookStats _stats;
  late PersonalRecords _records;
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _stats = widget.db.computeStats();
    _records = widget.db.personalRecords();
    _dates = [
      for (final d in widget.db.listDives())
        if (d.date != null) d.date!,
    ];
  }

  void _openDive(int id) {
    final dives = widget.db.listDives();
    final i = dives.indexWhere((d) => d.id == id);
    if (i < 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DiveDetailScreen(db: widget.db, dives: dives, initialIndex: i),
    ));
  }

  @override
  Widget build(BuildContext context) => StatsView(
        stats: _stats,
        dates: _dates,
        records: _records,
        onOpenRecord: _openDive,
      );
}
