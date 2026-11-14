/// Crear/editar un tipo de buceo: nombre + plantilla de botellas (litros+material)
/// que se añadirán automáticamente al elegir el tipo en un buceo.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/save_action.dart';
import 'package:pandive/features/dives/widgets/tank_edit_sheet.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DiveTypeEditScreen extends StatefulWidget {
  final DivemateDb db;
  final DiveType? type;
  const DiveTypeEditScreen({super.key, required this.db, this.type});

  @override
  State<DiveTypeEditScreen> createState() => _DiveTypeEditScreenState();
}

class _DiveTypeEditScreenState extends State<DiveTypeEditScreen> {
  late final _name = TextEditingController(text: widget.type?.name ?? '');
  late List<Cylinder> _tanks = [...?widget.type?.tanks];
  late final _presets = widget.db.listTankPresets();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addTank() async {
    final c = await showTankEditSheet(context, presets: _presets);
    if (c != null) setState(() => _tanks.add(c));
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (widget.type == null) {
      widget.db.addDiveType(name, _tanks);
    } else {
      widget.db.updateDiveType(widget.type!.id, name, _tanks);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == null ? t.newDiveType : t.diveType),
        actions: [SaveAction(saving: false, onSave: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(controller: _name, label: t.name),
          const SizedBox(height: 16),
          Text(t.tanks, style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < _tanks.length; i++)
            Card(
              child: ListTile(
                leading: const Icon(Icons.propane_tank_outlined),
                title: Text(
                    '${_tanks[i].size?.toStringAsFixed(1) ?? '—'} L · '
                    '${_tanks[i].material == TankMaterial.steel ? t.steel : t.aluminium}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _tanks.removeAt(i)),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addTank,
              icon: const Icon(Icons.add),
              label: Text(t.addTank),
            ),
          ),
        ],
      ),
    );
  }
}
