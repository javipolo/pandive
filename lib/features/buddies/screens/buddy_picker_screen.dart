/// Selección múltiple de compañeros (con crear nuevo). Devuelve `List<Buddy>`.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BuddyPickerScreen extends StatefulWidget {
  final DivemateDb db;
  final List<int> selectedIds;
  const BuddyPickerScreen({
    super.key,
    required this.db,
    this.selectedIds = const [],
  });

  @override
  State<BuddyPickerScreen> createState() => _BuddyPickerScreenState();
}

class _BuddyPickerScreenState extends State<BuddyPickerScreen> {
  late List<Buddy> _buddies = widget.db.listBuddies();
  late final Set<int> _selected = {...widget.selectedIds};

  Future<void> _createNew() async {
    final c = TextEditingController();
    final t = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.newBuddy),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: t.name),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: Text(t.create)),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = widget.db.findOrCreateBuddy(name);
    setState(() {
      _buddies = widget.db.listBuddies();
      _selected.add(id);
    });
  }

  void _confirm() {
    final chosen = _buddies.where((b) => _selected.contains(b.id)).toList();
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.selectBuddies),
        actions: [
          TextButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check),
            label: Text(t.confirm),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew,
        icon: const Icon(Icons.person_add),
        label: Text(t.create),
      ),
      body: _buddies.isEmpty
          ? Center(child: Text(t.noBuddies))
          : ListView.builder(
              itemCount: _buddies.length,
              itemBuilder: (context, i) {
                final b = _buddies[i];
                return CheckboxListTile(
                  value: _selected.contains(b.id),
                  title: Text(b.name),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(b.id);
                    } else {
                      _selected.remove(b.id);
                    }
                  }),
                );
              },
            ),
    );
  }
}
