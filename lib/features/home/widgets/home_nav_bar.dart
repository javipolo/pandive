/// Barra de navegación inferior de la pantalla principal (6 pestañas).
library;

import 'package:flutter/material.dart';

import 'package:pandive/l10n/app_localizations.dart';

class HomeNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const HomeNavBar(
      {super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        _dest(Icons.scuba_diving_outlined, Icons.scuba_diving, t.navDives),
        _dest(Icons.place_outlined, Icons.place, t.navSites),
        _dest(Icons.people_outline, Icons.people, t.buddies),
        _dest(Icons.label_outline, Icons.label, t.tags),
        _dest(Icons.tune_outlined, Icons.tune, t.equipment),
        _dest(Icons.bar_chart_outlined, Icons.bar_chart, t.navStats),
      ],
    );
  }

  NavigationDestination _dest(IconData icon, IconData selected, String label) =>
      NavigationDestination(
          icon: Icon(icon), selectedIcon: Icon(selected), label: label);
}
