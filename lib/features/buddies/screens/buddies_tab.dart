/// Pestaña de compañeros: lista, añadir, renombrar, eliminar (individual o en
/// lote), ver sus buceos.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'buddy_dives_screen.dart';

class BuddiesTab extends StatefulWidget {
  final DivemateDb db;
  final String query;
  const BuddiesTab({super.key, required this.db, this.query = ''});

  @override
  State<BuddiesTab> createState() => _BuddiesTabState();
}

class _BuddiesTabState extends State<BuddiesTab> {
  late List<Buddy> _buddies = widget.db.listBuddies();
  bool _select = false;
  final Set<int> _sel = {};

  void _reload() => setState(() => _buddies = widget.db.listBuddies());

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
      widget.db.deleteBuddy(id);
    }
    _exitSel();
    _reload();
  }

  Future<void> _add() async {
    final name = await nameDialog(context, AppLocalizations.of(context).newBuddy);
    if (name != null && name.isNotEmpty) {
      widget.db.findOrCreateBuddy(name);
      _reload();
    }
  }

  Future<void> _rename(Buddy b) async {
    final name = await nameDialog(context, AppLocalizations.of(context).rename,
        initial: b.name);
    if (name != null && name.isNotEmpty) {
      widget.db.renameBuddy(b.id, name);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final q = widget.query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _buddies
        : _buddies.where((b) => b.name.toLowerCase().contains(q)).toList();
    return Scaffold(
      floatingActionButton: _select
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.person_add),
              label: Text(t.addBuddy),
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
              ? Center(child: Text(t.noBuddies))
              : ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(shown[i], t),
                ),
        ),
      ]),
    );
  }

  Widget _tile(Buddy b, AppLocalizations t) {
    final selected = _sel.contains(b.id);
    return ListTile(
      selected: selected,
      leading: selected
          ? const CircleAvatar(child: Icon(Icons.check))
          : CircleAvatar(
              child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : '?')),
      title: Text(b.name),
      subtitle: Text(t.diveCountLabel(b.diveCount)),
      onLongPress: () => setState(() {
        _select = true;
        _sel.add(b.id);
      }),
      onTap: _select
          ? () => _toggle(b.id)
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BuddyDivesScreen(db: widget.db, buddy: b),
              )),
      trailing: _select
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') _rename(b);
                if (v == 'delete') {
                  widget.db.deleteBuddy(b.id);
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
