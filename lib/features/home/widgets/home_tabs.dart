/// Pestañas principales (IndexedStack). Escucha `dataRevision` para refrescar
/// sin reabrir la DB (reload blando tras escrituras en herramientas).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/buddies/screens/buddies_tab.dart';
import 'package:pandive/features/dives/screens/dives_screen.dart';
import 'package:pandive/features/equipment/screens/equipment_tab.dart';
import 'package:pandive/features/sites/screens/sites_screen.dart';
import 'package:pandive/features/stats/screens/stats_screen.dart';
import 'package:pandive/features/tags/screens/tags_tab.dart';

class HomeTabs extends StatelessWidget {
  final DivemateDb db;
  final Settings settings;
  final int index;
  final int version;
  final bool searching;
  final String query;
  final bool collapseAll;
  final bool sortByDives;
  const HomeTabs({
    super.key,
    required this.db,
    required this.settings,
    required this.index,
    required this.version,
    required this.searching,
    required this.query,
    required this.collapseAll,
    required this.sortByDives,
  });

  String _q(int i) => (searching && index == i) ? query : '';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: dataRevision,
      builder: (context, rev, _) {
        final v = '$version-$rev';
        return IndexedStack(
          index: index,
          children: [
            DivesTab(
                key: ValueKey('dives-$v'),
                db: db,
                settings: settings,
                query: _q(0),
                collapseAll: collapseAll),
            SitesTab(
                key: ValueKey('sites-$v'),
                db: db,
                settings: settings,
                query: _q(1),
                collapseAll: collapseAll,
                sortByDives: sortByDives),
            BuddiesTab(
                key: ValueKey('buddies-$v'),
                db: db,
                settings: settings,
                query: _q(2),
                sortByDives: sortByDives),
            TagsTab(
                key: ValueKey('tags-$v'),
                db: db,
                settings: settings,
                query: _q(3)),
            EquipmentTab(key: ValueKey('equip-$v'), db: db),
            StatsTab(key: ValueKey('stats-$v'), db: db),
          ],
        );
      },
    );
  }
}
