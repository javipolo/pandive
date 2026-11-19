/// Cabecera de grupo en la lista de inmersiones (año o mes), colapsable y
/// seleccionable en lote.
library;

import 'package:material_ui/material_ui.dart';

class DiveGroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool collapsed;
  final bool isYear;
  final bool selectedGroup;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const DiveGroupHeader({
    super.key,
    required this.label,
    required this.count,
    required this.collapsed,
    required this.isYear,
    required this.onTap,
    this.onLongPress,
    this.selectedGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selectedGroup
        ? cs.primary
        : (isYear ? cs.primaryContainer : cs.surfaceContainerHighest);
    final fg = selectedGroup
        ? cs.onPrimary
        : (isYear ? cs.onPrimaryContainer : cs.onSurface);
    return Material(
      color: bg,
      child: ListTile(
        dense: !isYear,
        contentPadding: EdgeInsets.only(left: isYear ? 16 : 32, right: 12),
        leading: selectedGroup ? Icon(Icons.check_circle, color: fg) : null,
        title: Text('${label.toUpperCase()}  ($count)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isYear ? 16 : 14,
                letterSpacing: 0.5,
                color: fg)),
        trailing: Icon(collapsed ? Icons.expand_more : Icons.expand_less,
            color: fg),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
