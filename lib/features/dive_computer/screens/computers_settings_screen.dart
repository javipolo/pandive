/// Ajustes: lista de ordenadores de buceo guardados, con opción de borrarlos.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ComputersSettingsScreen extends StatefulWidget {
  final DivemateDb db;
  const ComputersSettingsScreen({super.key, required this.db});

  @override
  State<ComputersSettingsScreen> createState() =>
      _ComputersSettingsScreenState();
}

class _ComputersSettingsScreenState extends State<ComputersSettingsScreen> {
  late List<DiveComputerRef> _list = widget.db.listComputers();

  void _reload() => setState(() => _list = widget.db.listComputers());

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.computers)),
      body: _list.isEmpty
          ? Center(child: Text(t.noComputers))
          : ListView.separated(
              itemCount: _list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = _list[i];
                return ListTile(
                  leading: const Icon(Icons.watch),
                  title: Text(c.name),
                  subtitle: Text(c.address),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      widget.db.removeComputer(c.address);
                      _reload();
                    },
                  ),
                );
              },
            ),
    );
  }
}
