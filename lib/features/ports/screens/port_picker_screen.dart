/// Port list: pick one (pops with the Port), create a new one (picked
/// straight away), edit or delete. Also the place where ports are managed.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/ports/screens/port_edit_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PortPickerScreen extends StatefulWidget {
  final DivemateDb db;
  final int? selectedId;
  const PortPickerScreen({super.key, required this.db, this.selectedId});

  @override
  State<PortPickerScreen> createState() => _PortPickerScreenState();
}

enum _Act { edit, delete }

class _PortPickerScreenState extends State<PortPickerScreen> {
  late List<Port> _ports = widget.db.listPorts();

  void _reload() => setState(() => _ports = widget.db.listPorts());

  Future<int?> _edit([Port? p]) => Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => PortEditScreen(db: widget.db, port: p),
    ),
  );

  Future<void> _new() async {
    final id = await _edit();
    if (id == null || !mounted) return;
    Navigator.of(context).pop(widget.db.getPort(id));
  }

  Future<void> _act(Port p, _Act a) async {
    final t = AppLocalizations.of(context);
    switch (a) {
      case _Act.edit:
        if (await _edit(p) != null) _reload();
      case _Act.delete:
        if (await confirmDialog(
          context,
          t.deletePortConfirm(p.name, p.useCount),
          confirmLabel: t.delete,
        )) {
          widget.db.deletePort(p.id);
          _reload();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.selectPort)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: Text(t.newPort),
      ),
      body: _ports.isEmpty
          ? Center(child: Text(t.noPorts))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final p in _ports)
                  ListTile(
                    selected: p.id == widget.selectedId,
                    leading: const Icon(Icons.directions_boat),
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        t.portUses(p.useCount),
                        if (!p.hasCoords) t.portNoLocation,
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.of(context).pop(p),
                    trailing: PopupMenuButton<_Act>(
                      onSelected: (a) => _act(p, a),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: _Act.edit, child: Text(t.edit)),
                        PopupMenuItem(
                          value: _Act.delete,
                          child: Text(t.delete),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
