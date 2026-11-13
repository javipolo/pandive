/// Ajustes de la app: idioma y tamaño de letra.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  final VoidCallback onChangeDb;
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChangeDb,
  });

  Future<void> _confirmChangeDb(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.menuChangeDb),
        content: Text(t.changeDbWarning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.menuChangeDb)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.pop(context); // cerrar ajustes
      onChangeDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final current = settings.locale?.languageCode; // null = sistema
        return Scaffold(
          appBar: AppBar(title: Text(t.settingsTitle)),
          body: ListView(
            children: [
              _header(context, t.language),
              RadioGroup<String?>(
                groupValue: current,
                onChanged: (v) => settings.setLocale(v),
                child: Column(
                  children: [
                    for (final opt in <(String?, String)>[
                      (null, t.languageSystem),
                      ('es', t.languageSpanish),
                      ('en', t.languageEnglish),
                    ])
                      RadioListTile<String?>(value: opt.$1, title: Text(opt.$2)),
                  ],
                ),
              ),
              const Divider(),
              _header(context, t.textSize),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(t.textSizeHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Text('A', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      min: Settings.minTextScale,
                      max: Settings.maxTextScale,
                      divisions: 12,
                      value: settings.textScale.clamp(
                          Settings.minTextScale, Settings.maxTextScale),
                      label: '${(settings.textScale * 100).round()}%',
                      onChanged: settings.setTextScale,
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                ],
              ),
              Center(
                child: TextButton(
                  onPressed: () =>
                      settings.setTextScale(Settings.defaultTextScale),
                  child: Text(t.reset),
                ),
              ),
              const Divider(),
              _header(context, t.database),
              ListTile(
                leading: Icon(Icons.swap_horiz,
                    color: Theme.of(context).colorScheme.error),
                title: Text(t.menuChangeDb),
                subtitle: Text(t.changeDbWarning),
                onTap: () => _confirmChangeDb(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
