/// Resultado de una descarga: resumen (total / nuevas / ya en DB) y lista de
/// las que NO existen aún, con botón para guardarlas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dive_computer/widgets/downloaded_dive_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

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
    final t = AppLocalizations.of(context);
    final existing = total - newDives.length;
    if (newDives.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t.allAlreadyInDb(total),
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
        label: Text(saving ? t.saving : t.saveN(newDives.length)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              t.downloadedSummary(total, newDives.length, existing),
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
