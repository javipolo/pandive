/// Indicador de progreso de descarga: rueda grande + % debajo (legible).
library;

import 'package:flutter/material.dart';

class DownloadProgress extends StatelessWidget {
  final double progress; // 0.0–1.0 (0 = indeterminado al principio)
  const DownloadProgress({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final determinate = progress > 0;
    final pct = (progress * 100).round();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CircularProgressIndicator(
              value: determinate ? progress : null,
              strokeWidth: 14,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            determinate ? '$pct %' : 'Conectando…',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Descargando del ordenador.\nMantenlo cerca y encendido.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
