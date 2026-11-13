/// Resultado de una descarga: resumen (total / nuevas / ya en DB) y lista de
/// las que NO existen aún, con botón para guardarlas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dive_computer/widgets/downloaded_dive_tile.dart';

class DownloadResultList extends StatelessWidget {
  final int total;
  final List<DownloadedDive> newDives;
  final bool saving;
  final VoidCallback onSave;

  const DownloadResultList({
    super.key,
    required this.total,
    required this.newDives,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final existing = total - newDives.length;
    if (newDives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Las $total inmersiones del ordenador ya están en tu logbook.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : onSave,
        icon: const Icon(Icons.save),
        label: Text(saving ? 'Guardando…' : 'Guardar ${newDives.length}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$total descargadas · ${newDives.length} nuevas'
              '${existing > 0 ? ' ($existing ya en la DB)' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: newDives.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => DownloadedDiveTile(dive: newDives[i]),
            ),
          ),
        ],
      ),
    );
  }
}
