/// Lista de inmersiones (de un sitio); al tocar una abre el detalle.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/screens/dive_detail_screen.dart';

class SiteDivesScreen extends StatelessWidget {
  final DivemateDb db;
  final String title;
  final List<Dive> dives;
  const SiteDivesScreen({
    super.key,
    required this.db,
    required this.title,
    required this.dives,
  });

  @override
  Widget build(BuildContext context) {
    final fmt =
        DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: dives.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final d = dives[i];
          final stats = [
            if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
            if (d.durationMin != null) '${d.durationMin!.round()} min',
          ].join('   ');
          return ListTile(
            leading: CircleAvatar(child: Text(d.number?.toString() ?? '—')),
            title: Text(d.date != null ? fmt.format(d.date!) : '—'),
            subtitle: stats.isEmpty ? null : Text(stats),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  DiveDetailScreen(db: db, dives: dives, initialIndex: i),
            )),
          );
        },
      ),
    );
  }
}
