/// Pantalla principal con navegación por pestañas: inmersiones, sitios, stats.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/buddies/screens/buddies_tab.dart';
import 'package:pandive/features/dive_computer/screens/dive_computer_screen.dart';
import 'package:pandive/features/dives/screens/dives_screen.dart';
import 'package:pandive/features/settings/screens/settings_screen.dart';
import 'package:pandive/features/sites/screens/sites_screen.dart';
import 'package:pandive/features/stats/screens/stats_screen.dart';
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

  void _openDiveComputer() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DiveComputerScreen(
            db: widget.db,
            settings: widget.settings,
          ),
        ))
        .then((_) {
      if (mounted) setState(() => _dataVersion++); // refrescar tras importar
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titles = [t.navDives, t.navSites, t.buddies, t.navStats];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: t.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(
                      settings: widget.settings,
                      onChangeDb: widget.onChangeDb,
                    ))),
          ),
          IconButton(
            tooltip: t.menuDiveComputer,
            icon: const Icon(Icons.bluetooth),
            onPressed: _openDiveComputer,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DivesTab(key: ValueKey('dives-$_dataVersion'), db: widget.db),
          SitesTab(key: ValueKey('sites-$_dataVersion'), db: widget.db),
          BuddiesTab(key: ValueKey('buddies-$_dataVersion'), db: widget.db),
          StatsTab(key: ValueKey('stats-$_dataVersion'), db: widget.db),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: t.navStats,
          ),
        ],
      ),
    );
  }
}
