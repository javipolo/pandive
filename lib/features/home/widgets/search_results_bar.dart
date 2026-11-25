/// Small line under the search bar with the tab's result count.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/features/dives/logic/dive_search.dart';
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
    switch (index) {
      case 0:
        return filterDives(db.listDives(), q).length;
      case 1:
        return db
            .listSites()
            .where((s) => foldContains(
                '${s.name ?? ''} ${s.country ?? ''} ${s.region ?? ''}', q))
            .length;
      case 2:
        return db.listBuddies().where((b) => foldContains(b.name, q)).length;
      case 3:
        return db.listTags().where((e) => foldContains(e.name, q)).length;
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
