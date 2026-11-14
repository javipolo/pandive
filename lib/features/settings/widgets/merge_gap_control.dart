/// Control del hueco máx. de fusión: slider + −/+ con el valor siempre visible.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/settings/settings.dart';

class MergeGapControl extends StatelessWidget {
  final Settings settings;
  const MergeGapControl({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final v = settings.mergeGapMinutes;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () => settings.setMergeGapMinutes(v - 1),
        ),
        Expanded(
          child: Slider(
            min: 1,
            max: 60,
            divisions: 59,
            value: v.clamp(1, 60).toDouble(),
            label: '$v min',
            onChanged: (x) => settings.setMergeGapMinutes(x.round()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => settings.setMergeGapMinutes(v + 1),
        ),
        SizedBox(
          width: 64,
          child: Text('$v min',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
