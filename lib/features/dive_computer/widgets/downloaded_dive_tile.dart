/// Fila de una inmersión descargada (fecha, prof, duración, nº muestras).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';

class DownloadedDiveTile extends StatelessWidget {
  final DownloadedDive dive;
  DownloadedDiveTile({super.key, required this.dive});

  final _fmt = DateFormat('d MMM yyyy, HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final d = dive;
    final stats = [
      if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
      if (d.divetimeSec != null) '${(d.divetimeSec! / 60).round()} min',
      '${d.samples.length} muestras',
    ].join('   ');
    return ListTile(
      leading: const Icon(Icons.download_done),
      title: Text(d.datetime != null ? _fmt.format(d.datetime!) : 'Inmersión'),
      subtitle: Text(stats),
    );
  }
}
