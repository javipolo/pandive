/// AppBar de la pantalla principal: título o buscador, y acciones (buscar,
/// colapsar grupos, ordenar por nº de buceos, ajustes).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/features/home/widgets/search_results_bar.dart';
import 'package:pandive/l10n/app_localizations.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DivemateDb db;
  final int index;
  final String title;
  final bool searching;
  final String query;
  final TextEditingController searchCtrl;
  final bool collapseAll;
  final bool sortByDives;
  final bool canSearch;
  final bool canCollapse;
  final bool canSort;
  final bool canMap;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onStartSearch;
  final VoidCallback onExitSearch;
  final VoidCallback onToggleCollapse;
  final VoidCallback onToggleSort;
  final VoidCallback onMap;
  final VoidCallback onSettings;
  const HomeAppBar({
    super.key,
    required this.db,
    required this.index,
    required this.title,
    required this.searching,
    required this.query,
    required this.searchCtrl,
    required this.collapseAll,
    required this.sortByDives,
    required this.canSearch,
    required this.canCollapse,
    required this.canSort,
    required this.canMap,
    required this.onQueryChanged,
    required this.onStartSearch,
    required this.onExitSearch,
    required this.onToggleCollapse,
    required this.onToggleSort,
    required this.onMap,
    required this.onSettings,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (searching && query.trim().isNotEmpty ? 48 : 0));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AppBar(
      bottom: (searching && query.trim().isNotEmpty)
          ? SearchResultsBar(db: db, index: index, query: query)
          : null,
      leading: searching
          ? IconButton(
              icon: const Icon(Icons.arrow_back), onPressed: onExitSearch)
          : null,
      title: searching
          ? TextField(
              controller: searchCtrl,
              autofocus: true,
              decoration:
                  InputDecoration(hintText: t.search, border: InputBorder.none),
              onChanged: onQueryChanged,
            )
          : Text(title),
      actions: searching
          ? [IconButton(icon: const Icon(Icons.clear), onPressed: onExitSearch)]
          : [
              if (canSearch)
                IconButton(
                    tooltip: t.search,
                    icon: const Icon(Icons.search),
                    onPressed: onStartSearch),
              if (canMap)
                IconButton(
                    tooltip: t.mapTitle,
                    icon: const Icon(Icons.map_outlined),
                    onPressed: onMap),
              if (canSort)
                IconButton(
                    tooltip: t.sortByDives,
                    icon: Icon(sortByDives
                        ? Icons.sort_by_alpha
                        : Icons.format_list_numbered),
                    onPressed: onToggleSort),
              if (canCollapse)
                IconButton(
                    iconSize: 30,
                    icon: Icon(
                        collapseAll ? Icons.unfold_more : Icons.unfold_less),
                    onPressed: onToggleCollapse)
              // En sitios, al ordenar por buceos desaparece colapsar: deja el
              // hueco para que el resto de iconos no se muevan.
              else if (canSort && index == 1)
                const SizedBox(width: 48),
              IconButton(
                  tooltip: t.settings,
                  icon: const Icon(Icons.settings),
                  onPressed: onSettings),
            ],
    );
  }
}
