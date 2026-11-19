/// Lista simple de inmersiones (p.ej. las de un tag/buddy/sitio) -> detalle.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'dive_detail_screen.dart';

class DivesListScreen extends StatelessWidget {
  final DivemateDb db;
  final String title;
  final List<Dive> dives;
  const DivesListScreen({
    super.key,
    required this.db,
    required this.title,
    required this.dives,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: dives.isEmpty
          ? Center(child: Text(t.noResults))
          : ListView.separated(
              itemCount: dives.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = dives[i];
                final sub = [d.place, d.country]
                    .whereType<String>()
                    .where((e) => e.isNotEmpty)
                    .join(' · ');
                return ListTile(
                  leading: CircleAvatar(child: Text(d.number?.toString() ?? '—')),
                  title: Text(sub.isEmpty ? t.dive : sub,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: d.date != null ? Text(fmt.format(d.date!)) : null,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DiveDetailScreen(
                        db: db, dives: dives, initialIndex: i),
                  )),
                );
              },
            ),
    );
  }
}
