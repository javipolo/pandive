/// Fila de inmersión estilo DiveMate: número grande a la izquierda (2 líneas),
/// nombre del sitio arriba y fecha/hora/tiempo/profundidad debajo.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DiveRow extends StatelessWidget {
  final Dive dive;
  final Settings settings;
  final bool isCave;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const DiveRow({
    super.key,
    required this.dive,
    required this.settings,
    this.isCave = false,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cs = Theme.of(context).colorScheme;
    final title = [dive.place, dive.country]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(', ');

    final parts = <String>[
      if (dive.date != null) DateFormat('dd/MM/yyyy HH:mm', locale).format(dive.date!),
      if (dive.durationMin != null) '${dive.durationMin!.round()} min',
      if (dive.maxDepth != null) '${NumberFormat('0.0', locale).format(dive.maxDepth)} m',
    ].join('   ');

    // Diurna (sol) vs nocturna (luna) según la hora de entrada (configurable).
    final hour = dive.date?.hour;
    final night = hour != null && settings.isNight(hour);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? cs.primaryContainer.withValues(alpha: 0.5) : null,
        foregroundDecoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dive.number?.toString() ?? '—',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ),
                  if (isCave)
                    const Text('🦇', style: TextStyle(fontSize: 16))
                  else if (hour != null)
                    Icon(
                      night ? Icons.nightlight_round : Icons.wb_sunny,
                      size: 18,
                      color: night ? cs.primary : Colors.amber,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.isEmpty ? t.dive : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(parts, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
