/// Control de tamaño de letra: slider + botones −/+ (paso 0.1).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/settings/settings.dart';

class TextScaleControl extends StatelessWidget {
  final Settings settings;
  const TextScaleControl({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: '−',
          onPressed: () => settings.setTextScale(settings.textScale - 0.1),
        ),
        Expanded(
          child: Slider(
            min: Settings.minTextScale,
            max: Settings.maxTextScale,
            divisions: 12,
            value: settings.textScale
                .clamp(Settings.minTextScale, Settings.maxTextScale),
            label: '${(settings.textScale * 100).round()}%',
            onChanged: settings.setTextScale,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '+',
          onPressed: () => settings.setTextScale(settings.textScale + 0.1),
        ),
      ],
    );
  }
}
