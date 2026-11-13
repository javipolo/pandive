/// Lista de inmersiones de un compañero concreto.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/screens/dive_detail_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BuddyDivesScreen extends StatelessWidget {
  final DivemateDb db;
  final Buddy buddy;
  const BuddyDivesScreen({super.key, required this.db, required this.buddy});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dives = db.listDivesByBuddy(buddy.id);
    final fmt = DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.divesWith(buddy.name))),
      body: dives.isEmpty
          ? Center(child: Text(t.noResults))
          : ListView.separated(
              itemCount: dives.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = dives[i];
                final sub = [
                  if (d.place != null) d.place!,
                  if (d.date != null) fmt.format(d.date!),
                ].join(' · ');
                return ListTile(
                  leading: CircleAvatar(child: Text(d.number?.toString() ?? '—')),
                  title: Text(sub.isEmpty ? t.dive : sub,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
