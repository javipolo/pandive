/// Menú lateral (hamburguesa) con las secciones que no están en la barra
/// inferior: etiquetas, equipo y estadísticas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/l10n/app_localizations.dart';

class HomeDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const HomeDrawer(
      {super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: cs.primaryContainer),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Pandive',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            _item(context, 3, Icons.label_outline, t.tags),
            _item(context, 4, Icons.tune_outlined, t.equipment),
            _item(context, 5, Icons.bar_chart_outlined, t.navStats),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selectedIndex == i,
      onTap: () {
        Navigator.pop(context);
        onSelected(i);
      },
    );
  }
}
