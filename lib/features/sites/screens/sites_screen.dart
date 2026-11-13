/// Pestaña de sitios de buceo (tabla Place) con nº de inmersiones y mapa.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

class SitesTab extends StatefulWidget {
  final DivemateDb db;
  const SitesTab({super.key, required this.db});

  @override
  State<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends State<SitesTab> {
  final _searchCtrl = TextEditingController();
  late List<DiveSite> _all;
  late List<DiveSite> _shown;

  @override
  void initState() {
    super.initState();
    _all = widget.db.listSites();
    _shown = _all;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final s = q.trim().toLowerCase();
    setState(() {
      _shown = s.isEmpty
          ? _all
          : _all.where((e) {
              return (e.name ?? '').toLowerCase().contains(s) ||
                  (e.country ?? '').toLowerCase().contains(s) ||
                  (e.region ?? '').toLowerCase().contains(s);
            }).toList();
    });
  }

  Future<void> _openMap(DiveSite site) async {
    if (!site.hasCoords) return;
    final uri = Uri.parse('geo:${site.lat},${site.lon}?q=${site.lat},${site.lon}'
        '(${Uri.encodeComponent(site.name ?? 'Punto de buceo')})');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Fallback a Google Maps web si no hay app de mapas.
      await launchUrl(
        Uri.parse('https://maps.google.com/?q=${site.lat},${site.lon}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: 'Buscar sitio, país, región…',
            leading: const Icon(Icons.search),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: _shown.isEmpty
              ? const Center(child: Text('Sin sitios'))
              : ListView.separated(
                  itemCount: _shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(_shown[i]),
                ),
        ),
      ],
    );
  }

  Widget _tile(DiveSite s) {
    final sub = [
      if (s.region != null) s.region!,
      if (s.country != null) s.country!,
    ].join(' · ');
    final extra = [
      if (s.maxDepth != null && s.maxDepth! > 0)
        'máx ${s.maxDepth!.toStringAsFixed(0)} m',
      if (s.rating != null && s.rating! > 0) '★' * s.rating!,
    ].join('   ');

    return ListTile(
      leading: CircleAvatar(child: Text('${s.diveCount}')),
      title: Text(s.name ?? 'Sitio', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sub.isNotEmpty) Text(sub),
          if (extra.isNotEmpty)
            Text(extra, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: s.hasCoords
          ? IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Abrir en mapa',
              onPressed: () => _openMap(s),
            )
          : null,
    );
  }
}
