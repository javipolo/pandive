/// Pestaña de compañeros: lista, añadir, renombrar, eliminar (individual o en
/// lote), ver sus buceos.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/features/buddies/logic/buddy_sort.dart';
import 'package:pandive/features/buddies/logic/merge_buddies_action.dart';
import 'package:pandive/features/buddies/widgets/buddy_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BuddiesTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String query;
  final bool sortByDives;
  const BuddiesTab(
      {super.key,
      required this.db,
      required this.settings,
      this.query = '',
      this.sortByDives = false});

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

  Future<void> _mergeSel() async {
    final sel = _buddies.where((b) => _sel.contains(b.id)).toList();
    if (await runMergeBuddies(context, widget.db, sel)) {
      _exitSel();
      _reload();
    }
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
        ? [..._buddies]
        : _buddies.where((b) => b.name.toLowerCase().contains(q)).toList();
    sortBuddies(shown, widget.sortByDives);
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
            if (_sel.length >= 2)
              IconButton(
                tooltip: t.mergeBuddies,
                icon: const Icon(Icons.merge_type),
                onPressed: _mergeSel,
              ),
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
                  padding: const EdgeInsets.only(bottom: 88), // hueco para el FAB
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(shown[i]),
                ),
        ),
      ]),
    );
  }

  Widget _tile(Buddy b) => BuddyTile(
        buddy: b,
        selected: _sel.contains(b.id),
        selectMode: _select,
        db: widget.db,
        settings: widget.settings,
        onToggle: () => _toggle(b.id),
        onLongPress: () => setState(() {
          _select = true;
          _sel.add(b.id);
        }),
        onRename: () => _rename(b),
        onDelete: () {
          widget.db.deleteBuddy(b.id);
          _reload();
        },
      );
}
