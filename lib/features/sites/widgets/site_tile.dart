/// Fila de un sitio de buceo: avatar, nombre, región · nº buceos, y opcional
/// icono "ojo" para ver su info. Toca para ver sus buceos.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SiteTile extends StatelessWidget {
  final DiveSite site;
  final VoidCallback onTap;
  final VoidCallback? onInfo;
  const SiteTile(
      {super.key, required this.site, required this.onTap, this.onInfo});

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
        leading: CircleAvatar(
            child: Text(nm.isEmpty ? '?' : nm.substring(0, 1).toUpperCase())),
        title: Text(site.name ?? t.site,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub),
        trailing: onInfo == null
            ? null
            : IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: t.site,
                onPressed: onInfo),
        onTap: onTap,
      ),
    );
  }
}
