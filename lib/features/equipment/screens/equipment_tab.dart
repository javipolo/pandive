/// Pestaña "Equipo": hub de configuración de tipos de buceo y de botella.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/features/dive_types/screens/dive_types_screen.dart';
import 'package:pandive/features/tank_types/screens/tank_types_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class EquipmentTab extends StatelessWidget {
  final DivemateDb db;
  const EquipmentTab({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.scuba_diving),
          title: Text(t.diveTypes),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DiveTypesScreen(db: db))),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.propane_tank_outlined),
          title: Text(t.tankTypes),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TankTypesScreen(db: db))),
        ),
      ],
    );
  }
}
