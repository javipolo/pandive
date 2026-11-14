/// Pantalla principal con navegación por pestañas: inmersiones, sitios, stats.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/buddies/screens/buddies_tab.dart';
import 'package:pandive/features/dives/screens/dives_screen.dart';
import 'package:pandive/features/settings/screens/settings_screen.dart';
import 'package:pandive/features/sites/screens/sites_screen.dart';
import 'package:pandive/features/stats/screens/stats_screen.dart';
import 'package:pandive/features/tags/screens/tags_tab.dart';
import 'package:pandive/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final VoidCallback onChangeDb;

  const HomeScreen({
    super.key,
    required this.db,
    required this.settings,
    required this.onChangeDb,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _dataVersion = 0; // se incrementa para forzar recarga de las pestañas
  bool _searching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  bool get _canSearch => _index == 0 || _index == 1; // inmersiones / sitios

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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titles = [t.navDives, t.navSites, t.buddies, t.tags, t.navStats];
    return Scaffold(
      appBar: AppBar(
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
            IconButton(
              tooltip: t.settings,
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                        settings: widget.settings,
                        db: widget.db,
                        onChangeDb: widget.onChangeDb,
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
              query: _index == 0 && _searching ? _query : ''),
          SitesTab(
              key: ValueKey('sites-$_dataVersion'),
              db: widget.db,
              query: _index == 1 && _searching ? _query : ''),
          BuddiesTab(key: ValueKey('buddies-$_dataVersion'), db: widget.db),
          TagsTab(key: ValueKey('tags-$_dataVersion'), db: widget.db),
          StatsTab(key: ValueKey('stats-$_dataVersion'), db: widget.db),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        // Recrear las pestañas al cambiar para reflejar cambios (nuevos sitios,
        // compañeros, tags, importaciones...).
        onDestinationSelected: (i) {
          _searchCtrl.clear();
          setState(() {
            _index = i;
            _dataVersion++;
            _searching = false;
            _query = '';
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.scuba_diving_outlined),
            selectedIcon: const Icon(Icons.scuba_diving),
            label: t.navDives,
          ),
          NavigationDestination(
            icon: const Icon(Icons.place_outlined),
            selectedIcon: const Icon(Icons.place),
            label: t.navSites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: t.buddies,
          ),
          NavigationDestination(
            icon: const Icon(Icons.label_outline),
            selectedIcon: const Icon(Icons.label),
            label: t.tags,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: t.navStats,
          ),
        ],
      ),
    );
  }
}
