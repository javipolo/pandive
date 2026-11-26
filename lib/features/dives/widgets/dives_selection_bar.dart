/// Dive selection bar: the frequent actions as icons (select all, stats,
/// merge, trip, delete) and the rest in an overflow menu (adjust time,
/// export, dive type, add/remove tag).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/l10n/app_localizations.dart';

enum _More { adjustTime, export, diveType, addTag, removeTag }

class DivesSelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onStats;
  final VoidCallback? onMerge;
  final VoidCallback onAdjustTime;
  final VoidCallback onExport;
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
        _More.adjustTime => onAdjustTime(),
        _More.export => onExport(),
        _More.diveType => onDiveType(),
        _More.addTag => onAddTag(),
        _More.removeTag => onRemoveTag(),
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    PopupMenuItem<_More> item(_More v, IconData icon, String label) =>
        PopupMenuItem(
          value: v,
          child: ListTile(
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
      IconButton(
          tooltip: t.merge, icon: const Icon(Icons.merge), onPressed: onMerge),
      IconButton(
          tooltip: t.assignToTrip,
          icon: const Icon(Icons.luggage),
          onPressed: onAssignTrip),
      IconButton(
          tooltip: t.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete),
      PopupMenuButton<_More>(
        onSelected: _onMore,
        itemBuilder: (_) => [
          item(_More.diveType, Icons.scuba_diving, t.bulkDiveType),
          item(_More.addTag, Icons.label_outline, t.bulkAddTag),
          item(_More.removeTag, Icons.label_off_outlined, t.bulkRemoveTag),
          item(_More.adjustTime, Icons.schedule, t.adjustTime),
          item(_More.export, Icons.share, t.exportSelection),
        ],
      ),
    ]);
  }
}
