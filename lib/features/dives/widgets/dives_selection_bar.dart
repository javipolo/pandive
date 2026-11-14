/// Barra de selección de inmersiones: estadísticas, fusionar y borrar.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DivesSelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onStats;
  final VoidCallback? onMerge;
  final VoidCallback onDelete;

  const DivesSelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onStats,
    required this.onMerge,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SelectionBar(count: count, onClose: onClose, actions: [
      IconButton(
          tooltip: t.navStats,
          icon: const Icon(Icons.bar_chart),
          onPressed: onStats),
      IconButton(
          tooltip: t.merge, icon: const Icon(Icons.merge), onPressed: onMerge),
      IconButton(
          tooltip: t.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete),
    ]);
  }
}
