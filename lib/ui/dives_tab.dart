/// Pestaña de inmersiones: búsqueda + lista.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/divemate_db.dart';
import '../models.dart';
import 'dive_detail_screen.dart';

class DivesTab extends StatefulWidget {
  final DivemateDb db;
  const DivesTab({super.key, required this.db});

  @override
  State<DivesTab> createState() => _DivesTabState();
}

class _DivesTabState extends State<DivesTab> {
  final _dateFmt = DateFormat('d MMM yyyy', 'es');
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

  void _search(String q) {
    setState(() => _dives = widget.db.listDives(search: q));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: 'Buscar sitio, país, nota, nº…',
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
              ? const Center(child: Text('Sin resultados'))
              : ListView.separated(
                  itemCount: _dives.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(_dives[i]),
                ),
        ),
      ],
    );
  }

  Widget _tile(Dive d) {
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
        subtitle.isEmpty ? 'Inmersión' : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.date != null) Text(_dateFmt.format(d.date!)),
          if (stats.isNotEmpty)
            Text(stats, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: d.date != null && stats.isNotEmpty,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DiveDetailScreen(db: widget.db, dive: d),
        ),
      ),
    );
  }
}
