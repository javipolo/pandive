/// Fila de un sitio de buceo: avatar, nombre, región · nº buceos, y opcional
/// icono "ojo" para ver su info. Toca para ver sus buceos; en modo selección
/// hace toggle y muestra check.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SiteTile extends StatelessWidget {
  final DiveSite site;
  final VoidCallback onTap;
  final VoidCallback? onInfo;
  final bool selected;
  final bool selectMode;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  const SiteTile({
    super.key,
    required this.site,
    required this.onTap,
    this.onInfo,
    this.selected = false,
    this.selectMode = false,
    this.onToggle,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sub = [if (site.region != null) site.region!, t.diveCountLabel(site.diveCount)]
        .join(' · ');
    final nm = (site.name ?? '').trim();
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5), width: 1)),
      ),
      child: ListTile(
        selected: selected,
        leading: selected
            ? const CircleAvatar(child: Icon(Icons.check))
            : CircleAvatar(
                child: Text(nm.isEmpty ? '?' : nm.substring(0, 1).toUpperCase())),
        title: Text(site.name ?? t.site,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub),
        trailing: selectMode || onInfo == null
            ? null
            : IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: t.site,
                onPressed: onInfo),
        onTap: selectMode ? onToggle : onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
