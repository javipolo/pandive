/// Pestaña de compañeros: lista, añadir, renombrar, eliminar, ver sus buceos.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
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

  void _reload() => setState(() => _buddies = widget.db.listBuddies());

  Future<String?> _nameDialog(String title, {String initial = ''}) {
    final c = TextEditingController(text: initial);
    final t = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
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
              child: Text(t.save)),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = await _nameDialog(AppLocalizations.of(context).newBuddy);
    if (name != null && name.isNotEmpty) {
      widget.db.findOrCreateBuddy(name);
      _reload();
    }
  }

  Future<void> _rename(Buddy b) async {
    final name =
        await _nameDialog(AppLocalizations.of(context).rename, initial: b.name);
    if (name != null && name.isNotEmpty) {
      widget.db.renameBuddy(b.id, name);
      _reload();
    }
  }

  void _delete(Buddy b) {
    widget.db.deleteBuddy(b.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final q = widget.query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _buddies
        : _buddies.where((b) => b.name.toLowerCase().contains(q)).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: Text(t.addBuddy),
      ),
      body: shown.isEmpty
          ? Center(child: Text(t.noBuddies))
          : ListView.separated(
              itemCount: shown.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _tile(shown[i], t),
            ),
    );
  }

  Widget _tile(Buddy b, AppLocalizations t) {
    return ListTile(
      leading: CircleAvatar(
          child: Text(b.name.isNotEmpty ? b.name[0].toUpperCase() : '?')),
      title: Text(b.name),
      subtitle: Text(t.diveCountLabel(b.diveCount)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BuddyDivesScreen(db: widget.db, buddy: b),
      )),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'rename' ? _rename(b) : _delete(b),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'rename', child: Text(t.rename)),
          PopupMenuItem(value: 'delete', child: Text(t.delete)),
        ],
      ),
    );
  }
}
