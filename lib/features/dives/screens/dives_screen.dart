/// Pestaña de inmersiones: búsqueda + lista.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'dive_detail_screen.dart';
import 'new_dive_screen.dart';

class DivesTab extends StatefulWidget {
  final DivemateDb db;
  const DivesTab({super.key, required this.db});

  @override
  State<DivesTab> createState() => _DivesTabState();
}

class _DivesTabState extends State<DivesTab> {
  final _searchCtrl = TextEditingController();
  late List<Dive> _dives;

  @override
  void initState() {
    super.initState();
    _dives = widget.db.listDives();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _dives = widget.db.listDives(search: _searchCtrl.text));
  }

  void _search(String q) {
    setState(() => _dives = widget.db.listDives(search: q));
  }

  Future<void> _newDive() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewDiveScreen(db: widget.db)),
    );
    if (created == true) {
      _searchCtrl.clear();
      setState(() => _dives = widget.db.listDives());
    }
  }

  Future<void> _openDetail(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiveDetailScreen(
          db: widget.db,
          dives: _dives,
          initialIndex: index,
        ),
      ),
    );
    _reload(); // refrescar por si se editó alguna inmersión
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newDive,
        icon: const Icon(Icons.add),
        label: Text(t.newDive),
      ),
      body: Column(
        children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: t.searchDives,
            leading: const Icon(Icons.search),
            trailing: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _search('');
                  },
                ),
            ],
            onChanged: _search,
          ),
        ),
        Expanded(
          child: _dives.isEmpty
              ? Center(child: Text(t.noResults))
              : ListView.separated(
                  itemCount: _dives.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(_dives[i], i),
                ),
        ),
        ],
      ),
    );
  }

  Widget _tile(Dive d, int index) {
    final dateFmt =
        DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    final subtitle = [
      if (d.place != null) d.place!,
      if (d.country != null) d.country!,
    ].join(' · ');
    final stats = [
      if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
      if (d.durationMin != null) '${d.durationMin!.round()} min',
      if (d.waterTemp != null) '${d.waterTemp!.toStringAsFixed(0)} °C',
    ].join('   ');

    return ListTile(
      leading: CircleAvatar(child: Text(d.number?.toString() ?? '—')),
      title: Text(
        subtitle.isEmpty ? AppLocalizations.of(context).dive : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.date != null) Text(dateFmt.format(d.date!)),
          if (stats.isNotEmpty)
            Text(stats, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: d.date != null && stats.isNotEmpty,
      onTap: () => _openDetail(index),
    );
  }
}
