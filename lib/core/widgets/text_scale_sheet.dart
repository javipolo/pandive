/// Hoja inferior para ajustar el tamaño de letra global (accesibilidad).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/settings/settings.dart';

Future<void> showTextScaleSheet(BuildContext context, Settings settings) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tamaño de letra',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'La inmersión más profunda no sirve de nada si no ves los números.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Slider(
                        min: Settings.minTextScale,
                        max: Settings.maxTextScale,
                        divisions: 12,
                        value: settings.textScale.clamp(
                            Settings.minTextScale, Settings.maxTextScale),
                        label: '${(settings.textScale * 100).round()}%',
                        onChanged: (v) => settings.setTextScale(v),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 28)),
                  ],
                ),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        settings.setTextScale(Settings.defaultTextScale),
                    child: const Text('Restablecer'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
