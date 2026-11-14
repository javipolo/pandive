/// Selectores de idioma y tema (claro/oscuro/automático) para Ajustes.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/l10n/app_localizations.dart';

class LanguageThemeSelectors extends StatelessWidget {
  final Settings settings;
  const LanguageThemeSelectors({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final current = settings.locale?.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, t.language),
        RadioGroup<String?>(
          groupValue: current,
          onChanged: (v) => settings.setLocale(v),
          child: Column(children: [
            for (final o in <(String?, String)>[
              (null, t.languageSystem),
              ('es', t.languageSpanish),
              ('en', t.languageEnglish),
            ])
              RadioListTile<String?>(value: o.$1, title: Text(o.$2)),
          ]),
        ),
        const Divider(),
        _header(context, t.theme),
        RadioGroup<ThemeMode>(
          groupValue: settings.themeMode,
          onChanged: (v) => v == null ? null : settings.setThemeMode(v),
          child: Column(children: [
            for (final o in <(ThemeMode, String)>[
              (ThemeMode.system, t.themeSystem),
              (ThemeMode.light, t.themeLight),
              (ThemeMode.dark, t.themeDark),
            ])
              RadioListTile<ThemeMode>(value: o.$1, title: Text(o.$2)),
          ]),
        ),
      ],
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
