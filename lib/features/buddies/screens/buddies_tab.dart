/// Pestaña de compañeros: lista, añadir, renombrar, eliminar (individual o en
/// lote), ver sus buceos.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/core/widgets/scroll_helpers.dart';
import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/features/buddies/logic/buddy_sort.dart';
import 'package:pandive/features/buddies/logic/merge_buddies_action.dart';
import 'package:pandive/features/buddies/widgets/buddy_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BuddiesTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String query;
  const BuddiesTab(
      {super.key,
      required this.db,
      required this.settings,
      this.query = ''});

  @override
  State<BuddiesTab> createState() => _BuddiesTabState();
}

class _BuddiesTabState extends State<BuddiesTab> {
  // Orden y preferencia de sección "antiguos", recordados durante la sesión.
  static BuddySort _lastSort = BuddySort.name;
  static bool _lastShowStale = true;

  late List<Buddy> _buddies = widget.db.listBuddies();
  bool _select = false;
  final Set<int> _sel = {};
  BuddySort _sort = _lastSort;
  bool _showStale = _lastShowStale; // agrupar los de >2 años en una sección
  bool _staleOpen = false; // sección "hace >2 años" (colapsada por defecto)
  int? _highlightId; // buddy recién añadido, para destacar/desplazar
  final _hlKey = GlobalKey();
  Timer? _hlTimer;

  @override
  void dispose() {
    _hlTimer?.cancel();
    super.dispose();
  }

  void _reload() => setState(() => _buddies = widget.db.listBuddies());

  void _flash(int id) {
    setState(() => _highlightId = id);
    scrollToHighlight(_hlKey);
    _hlTimer?.cancel();
    _hlTimer = Timer(const Duration(seconds: 3),
        () => mounted ? setState(() => _highlightId = null) : null);
  }
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
      final id = widget.db.findOrCreateBuddy(name);
      _reload();
      _flash(id);
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
    final q = widget.query.trim();
    final shown = q.isEmpty
        ? [..._buddies]
        : _buddies.where((b) => foldContains(b.name, q)).toList();
    sortBuddiesBy(shown, _sort);

    // Al buscar (o con la sección desactivada): lista plana. Si no: los que no
    // bucean contigo hace >2 años van a una sección colapsada al final.
    final now = DateTime.now();
    final cutoff = DateTime(now.year - 2, now.month, now.day);
    bool isStale(Buddy b) =>
        _showStale &&
        q.isEmpty &&
        b.lastDive != null &&
        b.lastDive!.isBefore(cutoff);
    final main = [for (final b in shown) if (!isStale(b)) b];
    final stale = [for (final b in shown) if (isStale(b)) b];

    final rows = <Widget>[
      for (final b in main) ...[_tile(b), const Divider(height: 1)],
      if (stale.isNotEmpty) _staleHeader(t, stale.length),
      if (stale.isNotEmpty && _staleOpen)
        for (final b in stale) ...[_tile(b), const Divider(height: 1)],
    ];

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
        if (!_select) _controls(t),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(t.noBuddies))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88), // hueco para el FAB
                  children: rows,
                ),
        ),
      ]),
    );
  }

  String _sortLabel(AppLocalizations t) => switch (_sort) {
        BuddySort.name => t.sortByName,
        BuddySort.dives => t.sortByDives,
        BuddySort.recent => t.sortRecent,
      };

  Widget _controls(AppLocalizations t) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(children: [
          FilterChip(
            label: Text(t.olderBuddies),
            selected: _showStale,
            onSelected: (v) => setState(() => _showStale = _lastShowStale = v),
          ),
          const Spacer(),
          PopupMenuButton<BuddySort>(
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = _lastSort = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: BuddySort.name, child: Text(t.sortByName)),
              PopupMenuItem(value: BuddySort.dives, child: Text(t.sortByDives)),
              PopupMenuItem(value: BuddySort.recent, child: Text(t.sortRecent)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sort, size: 20),
                const SizedBox(width: 6),
                Text(_sortLabel(t)),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
        ]),
      );

  Widget _staleHeader(AppLocalizations t, int n) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      tileColor: cs.primaryContainer,
      title: Text(t.staleBuddies(n),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
      trailing: Icon(_staleOpen ? Icons.expand_less : Icons.expand_more,
          color: cs.onPrimaryContainer),
      onTap: () => setState(() => _staleOpen = !_staleOpen),
    );
  }

  Widget _tile(Buddy b) {
    final tile = BuddyTile(
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
    if (b.id != _highlightId) return tile;
    return Container(
      key: _hlKey,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
      child: tile,
    );
  }
}
