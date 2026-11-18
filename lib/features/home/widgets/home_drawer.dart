/// Menú lateral (hamburguesa) con las secciones que no están en la barra
/// inferior: etiquetas, equipo y estadísticas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/backup/screens/backup_screen.dart';
import 'package:pandive/features/settings/screens/about_screen.dart';
import 'package:pandive/features/settings/screens/tools_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class HomeDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final DivemateDb db;
  final Settings settings;
  final VoidCallback onReloadDb;
  const HomeDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.db,
    required this.settings,
    required this.onReloadDb,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              color: cs.primaryContainer,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: SafeArea(
                bottom: false,
                child: Text(
                  'PanDive',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                ),
              ),
            ),
            _item(context, 3, Icons.label_outline, t.tags),
            _item(context, 4, Icons.tune_outlined, t.equipment),
            _item(context, 5, Icons.bar_chart_outlined, t.navStats),
            const Divider(),
            _push(context, Icons.build_outlined, t.tools,
                (_) => ToolsScreen(settings: settings, db: db)),
            _push(context, Icons.cloud_upload_outlined, t.backup,
                (_) => BackupScreen(settings: settings, onReloadDb: onReloadDb)),
            _push(context, Icons.info_outline, t.about, (_) => const AboutScreen()),
          ],
        ),
      ),
    );
  }

  Widget _push(BuildContext context, IconData icon, String label,
      WidgetBuilder builder) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(builder: builder));
      },
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
