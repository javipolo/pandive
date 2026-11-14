/// Fila seleccionable de una inmersión descargada (fecha, prof, duración,
/// nº muestras). Marca las "pendientes" (reaparecidas de una descarga previa).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DownloadedDiveTile extends StatelessWidget {
  final DownloadedDive dive;
  final bool selected;
  final bool pending;
  final ValueChanged<bool> onChanged;

  const DownloadedDiveTile({
    super.key,
    required this.dive,
    required this.selected,
    required this.onChanged,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat(
        'd MMM yyyy, HH:mm', Localizations.localeOf(context).languageCode);
    final d = dive;
    final stats = [
      if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
      if (d.divetimeSec != null) '${(d.divetimeSec! / 60).round()} min',
      t.samplesCount(d.samples.length),
    ].join('   ');
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(d.datetime != null ? fmt.format(d.datetime!) : t.dive),
      subtitle: Text(stats),
      secondary: pending
          ? Chip(
              label: Text(t.pendingBadge),
              visualDensity: VisualDensity.compact)
          : null,
    );
  }
}
