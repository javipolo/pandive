/// Barras horizontales etiqueta/valor (inmersiones por periodo).
library;

import 'package:flutter/material.dart';

class PeriodBars extends StatelessWidget {
  final List<(String, int)> data; // ordenado
  const PeriodBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.fold<int>(1, (m, e) => e.$2 > m ? e.$2 : m);
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (label, count) in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth * (count / maxCount);
                      return Stack(
                        children: [
                          _bar(cs.surfaceContainerHighest, c.maxWidth),
                          _bar(cs.primary, w.clamp(2, c.maxWidth)),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$count',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bar(Color color, double width) => Container(
        height: 22,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}
