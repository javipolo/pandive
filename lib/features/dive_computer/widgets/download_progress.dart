/// Indicador de progreso de descarga (circular con %).
library;

import 'package:flutter/material.dart';

class DownloadProgress extends StatelessWidget {
  final double progress; // 0.0–1.0 (0 = indeterminado al principio)
  const DownloadProgress({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    final determinate = progress > 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: determinate ? progress : null,
                  strokeWidth: 8,
                ),
                if (determinate)
                  Text('$pct%', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Conectando y descargando…\nMantén el ordenador cerca y encendido.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
