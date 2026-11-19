/// Línea pequeña bajo la barra de búsqueda con el nº de resultados del tab.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SearchResultsBar extends StatelessWidget implements PreferredSizeWidget {
  final DivemateDb db;
  final int index;
  final String query;
  const SearchResultsBar(
      {super.key, required this.db, required this.index, required this.query});

  @override
  Size get preferredSize => const Size.fromHeight(22);

  int _count() {
    final q = query.trim();
    if (q.isEmpty) return 0;
    final ql = q.toLowerCase();
    switch (index) {
      case 0:
        return db.listDives(search: q).length;
      case 1:
        return db
            .listSites()
            .where((s) => '${s.name ?? ''} ${s.country ?? ''} ${s.region ?? ''}'
                .toLowerCase()
                .contains(ql))
            .length;
      case 2:
        return db.listBuddies().where((b) => b.name.toLowerCase().contains(ql)).length;
      case 3:
        return db.listTags().where((e) => e.name.toLowerCase().contains(ql)).length;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 6),
        child: Text(t.resultsFound(_count()),
            style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
