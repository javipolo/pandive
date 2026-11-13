/// Pantalla principal con navegación por pestañas: inmersiones, sitios, stats.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/text_scale_sheet.dart';
import 'package:pandive/features/dive_computer/screens/dive_computer_screen.dart';
import 'package:pandive/features/dives/screens/dives_screen.dart';
import 'package:pandive/features/sites/screens/sites_screen.dart';
import 'package:pandive/features/stats/screens/stats_screen.dart';

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

  static const _titles = ['Inmersiones', 'Sitios', 'Estadísticas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Tamaño de letra',
            icon: const Icon(Icons.format_size),
            onPressed: () => showTextScaleSheet(context, widget.settings),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'change_db') {
                widget.onChangeDb();
              } else if (v == 'dive_computer') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DiveComputerScreen(
                      db: widget.db,
                      settings: widget.settings,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'dive_computer',
                child: Text('Ordenador de buceo'),
              ),
              PopupMenuItem(
                value: 'change_db',
                child: Text('Cambiar base de datos'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DivesTab(db: widget.db),
          SitesTab(db: widget.db),
          StatsTab(db: widget.db),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.scuba_diving_outlined),
            selectedIcon: Icon(Icons.scuba_diving),
            label: 'Inmersiones',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Sitios',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
