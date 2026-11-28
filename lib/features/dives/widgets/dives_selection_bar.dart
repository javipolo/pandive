/// Dive selection bar: select all and stats as icons, everything else in an
/// overflow menu (dive type, tags, time, trip, merge, export, delete).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/l10n/app_localizations.dart';

enum _More {
  diveType,
  addTag,
  removeTag,
  adjustTime,
  assignTrip,
  merge,
  export,
  delete,
}

class DivesSelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onStats;
  final VoidCallback? onMerge;
  final VoidCallback onAdjustTime;
  final VoidCallback? onExport; // null = hidden (web)
  final VoidCallback onAssignTrip;
  final VoidCallback onDiveType;
  final VoidCallback onAddTag;
  final VoidCallback onRemoveTag;
  final VoidCallback onDelete;
  final VoidCallback onSelectAll;
  final bool allSelected;

  const DivesSelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onStats,
    required this.onMerge,
    required this.onAdjustTime,
    required this.onExport,
    required this.onAssignTrip,
    required this.onDiveType,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onDelete,
    required this.onSelectAll,
    required this.allSelected,
  });

  void _onMore(_More m) => switch (m) {
        _More.diveType => onDiveType(),
        _More.addTag => onAddTag(),
        _More.removeTag => onRemoveTag(),
        _More.adjustTime => onAdjustTime(),
        _More.assignTrip => onAssignTrip(),
        _More.merge => onMerge?.call(),
        _More.export => onExport?.call(),
        _More.delete => onDelete(),
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    PopupMenuItem<_More> item(_More v, IconData icon, String label,
            {bool enabled = true}) =>
        PopupMenuItem(
          value: v,
          enabled: enabled,
          child: ListTile(
              enabled: enabled,
              leading: Icon(icon),
              title: Text(label),
              contentPadding: EdgeInsets.zero),
        );
    return SelectionBar(count: count, onClose: onClose, actions: [
      IconButton(
          tooltip: allSelected ? t.deselectAll : t.selectAll,
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          onPressed: onSelectAll),
      IconButton(
          tooltip: t.navStats,
          icon: const Icon(Icons.bar_chart),
          onPressed: onStats),
      PopupMenuButton<_More>(
        onSelected: _onMore,
        itemBuilder: (_) => [
          item(_More.diveType, Icons.scuba_diving, t.bulkDiveType),
          item(_More.addTag, Icons.label_outline, t.bulkAddTag),
          item(_More.removeTag, Icons.label_off_outlined, t.bulkRemoveTag),
          item(_More.adjustTime, Icons.schedule, t.adjustTime),
          item(_More.assignTrip, Icons.luggage, t.assignToTrip),
          item(_More.merge, Icons.merge, t.merge, enabled: onMerge != null),
          if (onExport != null)
            item(_More.export, Icons.share, t.exportSelection),
          const PopupMenuDivider(),
          item(_More.delete, Icons.delete_outline, t.delete),
        ],
      ),
    ]);
  }
}
