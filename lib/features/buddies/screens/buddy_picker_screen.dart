/// Multiple buddy selection (with create new). Returns `List<Buddy>`.
/// Search by name, dive count per row and configurable order
/// (alphabetical by default, by dive count or by most recent dive).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/features/buddies/logic/buddy_sort.dart';
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
  // Remembers the chosen order between openings (only during the session).
  static BuddySort _lastSort = BuddySort.name;

  late List<Buddy> _buddies = widget.db.listBuddies();
  late final Set<int> _selected = {...widget.selectedIds};
  final _searchCtrl = TextEditingController();
  String _query = '';
  BuddySort _sort = _lastSort;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Buddy> _shown() {
    final q = _query.trim();
    final list = q.isEmpty
        ? [..._buddies]
        : _buddies.where((b) => foldContains(b.name, q)).toList();
    sortBuddiesBy(list, _sort);
    return list;
  }

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
    final shown = _shown();
    return Scaffold(
      appBar: AppBar(
        title: Text(t.selectBuddies),
        actions: [
          PopupMenuButton<BuddySort>(
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = _lastSort = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: BuddySort.name, child: Text(t.sortByName)),
              PopupMenuItem(value: BuddySort.dives, child: Text(t.sortByDives)),
              PopupMenuItem(value: BuddySort.recent, child: Text(t.sortRecent)),
            ],
          ),
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
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: t.search,
            leading: const Icon(Icons.search),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(t.noBuddies))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final b = shown[i];
                    return CheckboxListTile(
                      value: _selected.contains(b.id),
                      title: Text(b.name),
                      subtitle: Text(t.diveCountLabel(b.diveCount)),
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
        ),
      ]),
    );
  }
}
