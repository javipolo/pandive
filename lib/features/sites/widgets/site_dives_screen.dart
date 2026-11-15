/// Lista de inmersiones de un sitio concreto (al tocar el nombre en la lista).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/screens/dive_detail_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SiteDivesScreen extends StatelessWidget {
  final DivemateDb db;
  final DiveSite site;
  const SiteDivesScreen({super.key, required this.db, required this.site});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dives = db.listDivesBySite(site.id);
    final fmt =
        DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(site.name ?? t.site)),
      body: dives.isEmpty
          ? Center(child: Text(t.noResults))
          : ListView.separated(
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
