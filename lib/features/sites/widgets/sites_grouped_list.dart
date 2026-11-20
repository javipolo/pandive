/// Lista de sitios de buceo agrupada por país, con cabeceras colapsables y
/// buscador. Reutilizada por la pestaña de sitios y por el selector.
library;

import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/features/sites/widgets/site_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitesGroupedList extends StatefulWidget {
  final List<DiveSite> sites;
  final void Function(DiveSite) onTap;
  /// Si se pasa, el tile muestra un icono "ojo" a la derecha para ver la info.
  final void Function(DiveSite)? onInfo;
  /// Si se pasa, el filtro viene de fuera (barra superior) y se oculta la barra
  /// de búsqueda interna. Si es null, se muestra la barra interna (p.ej. picker).
  final String? externalQuery;
  final bool collapseAll;
  final bool sortByDives;
  const SitesGroupedList({
    super.key,
    required this.sites,
    required this.onTap,
    this.onInfo,
    this.externalQuery,
    this.collapseAll = false,
    this.sortByDives = false,
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
  List<DiveSite> _filtered() {
    final q = (widget.externalQuery ?? _q).trim().toLowerCase();
    if (q.isEmpty) return widget.sites;
    return [
      for (final s in widget.sites)
        if (('${s.name ?? ''} ${s.country ?? ''} ${s.region ?? ''}')
            .toLowerCase()
            .contains(q))
          s
    ];
  }
  Map<String, List<DiveSite>> _grouped() {
    final map = <String, List<DiveSite>>{};
    for (final s in _filtered()) {
      (map[s.country ?? '—'] ??= []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => compareFold(a.name ?? '', b.name ?? ''));
    }
    return map;
  }
  // Orden por nº de buceos: lista plana (sin agrupar por país) global.
  List<DiveSite> _byDives() => _filtered().toList()
    ..sort((a, b) => a.diveCount != b.diveCount
        ? b.diveCount.compareTo(a.diveCount)
        : compareFold(a.name ?? '', b.name ?? ''));
  // Filas agrupadas por país (cabeceras colapsables), orden alfabético.
  List<Widget> _groupedRows(BuildContext context) {
    final grouped = _grouped();
    final countries = grouped.keys.toList()..sort(compareFold);
    return [
      for (final c in countries) ...[
        _header(context, c, grouped[c]!.length),
        if (!_collapsed.contains(c))
          for (final s in grouped[c]!) _tile(s),
      ],
    ];
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = widget.sortByDives
        ? [for (final s in _byDives()) _tile(s)]
        : _groupedRows(context);
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
          child: rows.isEmpty
              ? Center(child: Text(t.noSitesYet))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88), // hueco para el FAB
                  children: rows,
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
  Widget _tile(DiveSite s) => SiteTile(
        site: s,
        onTap: () => widget.onTap(s),
        onInfo: widget.onInfo == null ? null : () => widget.onInfo!(s),
      );
}
