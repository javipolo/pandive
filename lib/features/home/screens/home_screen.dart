/// Pantalla principal con navegación por pestañas: inmersiones, sitios, stats.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/buddies/screens/buddies_tab.dart';
import 'package:pandive/features/dives/screens/dives_screen.dart';
import 'package:pandive/features/equipment/screens/equipment_tab.dart';
import 'package:pandive/features/home/widgets/home_drawer.dart';
import 'package:pandive/features/home/widgets/home_nav_bar.dart';
import 'package:pandive/features/home/widgets/search_results_bar.dart';
import 'package:pandive/features/settings/screens/settings_screen.dart';
import 'package:pandive/features/sites/screens/sites_screen.dart';
import 'package:pandive/features/stats/screens/stats_screen.dart';
import 'package:pandive/features/tags/screens/tags_tab.dart';
import 'package:pandive/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final VoidCallback onChangeDb;
  final VoidCallback onReloadDb;
  const HomeScreen({
    super.key,
    required this.db,
    required this.settings,
    required this.onChangeDb,
    required this.onReloadDb,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _dataVersion = 0; // se incrementa para forzar recarga de las pestañas
  bool _searching = false;
  String _query = '';
  bool _collapseAll = false;
  final _searchCtrl = TextEditingController();
  bool get _canSearch => _index <= 3; // todas menos estadísticas
  bool get _canCollapse => _index == 0 || _index == 1; // inmersiones / sitios
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  void _exitSearch() {
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }
  // Cambia de sección (barra inferior o menú lateral) y recarga datos.
  void _go(int i) {
    _searchCtrl.clear();
    setState(() {
      _index = i;
      _dataVersion++;
      _searching = false;
      _query = '';
    });
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titles = [
      t.navDives, t.navSites, t.buddies, t.tags, t.equipment, t.navStats];
    return Scaffold(
      drawer: HomeDrawer(selectedIndex: _index, onSelected: _go),
      appBar: AppBar(
        bottom: (_searching && _query.trim().isNotEmpty)
            ? SearchResultsBar(db: widget.db, index: _index, query: _query)
            : null,
        leading: _searching
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _exitSearch)
            : null,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: t.search, border: InputBorder.none),
                onChanged: (q) => setState(() => _query = q),
              )
            : Text(titles[_index]),
        actions: [
          if (_searching)
            IconButton(icon: const Icon(Icons.clear), onPressed: _exitSearch)
          else ...[
            if (_canSearch)
              IconButton(
                tooltip: t.search,
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _searching = true),
              ),
            if (_canCollapse)
              IconButton(
                tooltip: '',
                iconSize: 30,
                icon: Icon(_collapseAll ? Icons.unfold_more : Icons.unfold_less),
                onPressed: () => setState(() => _collapseAll = !_collapseAll),
              ),
            IconButton(
              tooltip: t.settings,
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                        settings: widget.settings,
                        db: widget.db,
                        onChangeDb: widget.onChangeDb,
                        onReloadDb: widget.onReloadDb,
                      ))),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DivesTab(
              key: ValueKey('dives-$_dataVersion'),
              db: widget.db,
              settings: widget.settings,
              query: _index == 0 && _searching ? _query : '',
              collapseAll: _collapseAll),
          SitesTab(
              key: ValueKey('sites-$_dataVersion'),
              db: widget.db,
              query: _index == 1 && _searching ? _query : '',
              collapseAll: _collapseAll),
          BuddiesTab(
              key: ValueKey('buddies-$_dataVersion'),
              db: widget.db,
              query: _index == 2 && _searching ? _query : ''),
          TagsTab(
              key: ValueKey('tags-$_dataVersion'),
              db: widget.db,
              query: _index == 3 && _searching ? _query : ''),
          EquipmentTab(key: ValueKey('equip-$_dataVersion'), db: widget.db),
          StatsTab(key: ValueKey('stats-$_dataVersion'), db: widget.db),
        ],
      ),
      bottomNavigationBar: HomeNavBar(selectedIndex: _index, onSelected: _go),
    );
  }
}
