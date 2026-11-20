/// Pestaña de etiquetas (tags): lista, crear, renombrar, borrar (individual o
/// en lote), ver buceos.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/features/dives/screens/filtered_dives_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TagsTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String query;
  const TagsTab(
      {super.key, required this.db, required this.settings, this.query = ''});

  @override
  State<TagsTab> createState() => _TagsTabState();
}

class _TagsTabState extends State<TagsTab> {
  late List<Tag> _tags = widget.db.listTags();
  bool _select = false;
  final Set<int> _sel = {};

  void _reload() => setState(() => _tags = widget.db.listTags());

  void _exitSel() => setState(() {
        _select = false;
        _sel.clear();
      });

  void _toggle(int id) => setState(() {
        if (!_sel.remove(id)) _sel.add(id);
        if (_sel.isEmpty) _select = false;
      });

  Future<void> _deleteSel() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deleteConfirm(_sel.length),
        confirmLabel: t.delete)) {
      return;
    }
    for (final id in _sel) {
      widget.db.deleteTag(id);
    }
    _exitSel();
    _reload();
  }

  Future<void> _edit({Tag? tag}) async {
    final t = AppLocalizations.of(context);
    final name = await nameDialog(context, tag == null ? t.newTag : t.rename,
        initial: tag?.name ?? '', confirmLabel: tag == null ? t.create : t.save);
    if (name == null || name.isEmpty) return;
    if (tag == null) {
      widget.db.findOrCreateTag(name);
    } else {
      widget.db.renameTag(tag.id, name);
    }
    _reload();
  }

  void _openDives(Tag tag) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FilteredDivesScreen(
        db: widget.db,
        settings: widget.settings,
        title: tag.name,
        loader: () => widget.db.listDivesByTag(tag.id),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final q = widget.query.trim();
    final shown = q.isEmpty
        ? _tags
        : _tags.where((e) => foldContains(e.name, q)).toList();
    return Scaffold(
      floatingActionButton: _select
          ? null
          : FloatingActionButton(
              onPressed: () => _edit(),
              child: const Icon(Icons.add),
            ),
      body: Column(children: [
        if (_select)
          SelectionBar(count: _sel.length, onClose: _exitSel, actions: [
            IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSel,
            ),
          ]),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(t.noTags))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88), // hueco para el FAB
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(shown[i], t),
                ),
        ),
      ]),
    );
  }

  Widget _tile(Tag tag, AppLocalizations t) {
    final selected = _sel.contains(tag.id);
    return ListTile(
      selected: selected,
      leading: Icon(selected ? Icons.check_circle : Icons.label_outline),
      title: Text(tag.name),
      onLongPress: () => setState(() {
        _select = true;
        _sel.add(tag.id);
      }),
      onTap: _select ? () => _toggle(tag.id) : () => _openDives(tag),
      trailing: _select
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') _edit(tag: tag);
                if (v == 'delete') {
                  widget.db.deleteTag(tag.id);
                  _reload();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(t.rename)),
                PopupMenuItem(value: 'delete', child: Text(t.delete)),
              ],
            ),
    );
  }
}
