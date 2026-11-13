/// Selección múltiple de etiquetas (tags): elegir existentes o crear nuevas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TagPickerScreen extends StatefulWidget {
  final DivemateDb db;
  final List<int> selectedIds;
  const TagPickerScreen({super.key, required this.db, this.selectedIds = const []});

  @override
  State<TagPickerScreen> createState() => _TagPickerScreenState();
}

class _TagPickerScreenState extends State<TagPickerScreen> {
  late List<Tag> _tags = widget.db.listTags();
  late final Set<int> _sel = {...widget.selectedIds};

  Future<void> _create() async {
    final t = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.newTag),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: t.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(t.create)),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = widget.db.findOrCreateTag(name);
    setState(() {
      _tags = widget.db.listTags();
      _sel.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.selectTags), actions: [
        TextButton(
          onPressed: () => Navigator.pop(
              context, [for (final tag in _tags) if (_sel.contains(tag.id)) tag]),
          child: Text(t.confirm),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _tags.isEmpty
          ? Center(child: Text(t.noTags))
          : ListView(
              children: [
                for (final tag in _tags)
                  CheckboxListTile(
                    value: _sel.contains(tag.id),
                    title: Text(tag.name),
                    onChanged: (v) => setState(() =>
                        v == true ? _sel.add(tag.id) : _sel.remove(tag.id)),
                  ),
              ],
            ),
    );
  }
}
