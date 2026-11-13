/// Fila de una inmersión descargada (fecha, prof, duración, nº muestras).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DownloadedDiveTile extends StatelessWidget {
  final DownloadedDive dive;
  const DownloadedDiveTile({super.key, required this.dive});

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
    return ListTile(
      leading: const Icon(Icons.download_done),
      title: Text(d.datetime != null ? fmt.format(d.datetime!) : t.dive),
      subtitle: Text(stats),
    );
  }
}
