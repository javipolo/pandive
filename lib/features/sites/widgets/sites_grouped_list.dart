/// Lista de sitios de buceo agrupada por país, con cabeceras colapsables y
/// buscador. Reutilizada por la pestaña de sitios y por el selector.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitesGroupedList extends StatefulWidget {
  final List<DiveSite> sites;
  final void Function(DiveSite) onTap;
  /// Si se pasan, el tile muestra un menú editar/borrar a la derecha (pestaña de
  /// sitios). En el selector se omiten y el tile solo selecciona.
  final void Function(DiveSite)? onEdit;
  final void Function(DiveSite)? onDelete;
  /// Si se pasa, el filtro viene de fuera (barra superior) y se oculta la barra
  /// de búsqueda interna. Si es null, se muestra la barra interna (p.ej. picker).
  final String? externalQuery;
  final bool collapseAll;
  const SitesGroupedList({
    super.key,
    required this.sites,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.externalQuery,
    this.collapseAll = false,
  });

  @override
  State<SitesGroupedList> createState() => _SitesGroupedListState();
}

class _SitesGroupedListState extends State<SitesGroupedList> {
  final _searchCtrl = TextEditingController();
  final _collapsed = <String>{};
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  @override
  void didUpdateWidget(SitesGroupedList old) {
    super.didUpdateWidget(old);
    if (old.collapseAll != widget.collapseAll) {
      _collapsed
        ..clear()
        ..addAll(widget.collapseAll
            ? widget.sites.map((s) => s.country ?? '—')
            : const []);
    }
  }
  Map<String, List<DiveSite>> _grouped() {
    final q = (widget.externalQuery ?? _q).trim().toLowerCase();
    final map = <String, List<DiveSite>>{};
    for (final s in widget.sites) {
      if (q.isNotEmpty &&
          !('${s.name ?? ''} ${s.country ?? ''} ${s.region ?? ''}')
              .toLowerCase()
              .contains(q)) {
        continue;
      }
      (map[s.country ?? '—'] ??= []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => compareFold(a.name ?? '', b.name ?? ''));
    }
    return map;
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final grouped = _grouped();
    final countries = grouped.keys.toList()..sort(compareFold);
    return Column(
      children: [
        if (widget.externalQuery == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: t.searchSites,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
        Expanded(
          child: countries.isEmpty
              ? Center(child: Text(t.noSitesYet))
              : ListView(
                  children: [
                    for (final c in countries) ...[
                      _header(context, c, grouped[c]!.length),
                      if (!_collapsed.contains(c))
                        for (final s in grouped[c]!) _tile(context, t, s),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
  Widget _header(BuildContext context, String country, int n) {
    final collapsed = _collapsed.contains(country);
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      tileColor: cs.primaryContainer,
      title: Text('${country.toUpperCase()}  ($n)',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: cs.onPrimaryContainer)),
      trailing: Icon(collapsed ? Icons.expand_more : Icons.expand_less,
          color: cs.onPrimaryContainer),
      onTap: () => setState(() =>
          collapsed ? _collapsed.remove(country) : _collapsed.add(country)),
    );
  }

  Widget _tile(BuildContext context, AppLocalizations t, DiveSite s) {
    final sub = [
      if (s.region != null) s.region!,
      t.diveCountLabel(s.diveCount),
    ].join(' · ');
    final nm = (s.name ?? '').trim();
    return ListTile(
      leading: CircleAvatar(
          child: Text(nm.isEmpty ? '?' : nm.substring(0, 1).toUpperCase())),
      title: Text(s.name ?? t.site,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub),
      onTap: () => widget.onTap(s),
      trailing: widget.onEdit == null
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'edit' ? widget.onEdit!(s) : widget.onDelete!(s),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(t.edit)),
                PopupMenuItem(value: 'delete', child: Text(t.delete)),
              ],
            ),
    );
  }
}
