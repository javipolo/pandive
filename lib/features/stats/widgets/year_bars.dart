/// Barras horizontales de inmersiones por año.
library;

import 'package:flutter/material.dart';

class YearBars extends StatelessWidget {
  final Map<int, int> data;
  const YearBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final years = data.keys.toList()..sort();
    final maxCount = data.values.fold<int>(1, (m, v) => v > m ? v : m);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final y in years)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('$y',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth * (data[y]! / maxCount);
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
                  child: Text('${data[y]}',
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
