import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/locale_resolution.dart';
import 'package:pandive/l10n/app_localizations.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  test('English (any region) runs as en_GB: day/month/year, 24 h', () {
    for (final l in const [Locale('en'), Locale('en', 'US'), Locale('en', 'GB')]) {
      expect(resolveAppLocale([l], supported), const Locale('en', 'GB'));
    }
  });

  test('other supported languages are kept', () {
    expect(resolveAppLocale(const [Locale('es', 'ES')], supported).languageCode,
        'es');
    expect(resolveAppLocale(const [Locale('fr')], supported).languageCode, 'fr');
  });

  test('unsupported language falls back like before (first supported)', () {
    final r = resolveAppLocale(const [Locale('ja')], supported);
    final base = basicLocaleListResolution(const [Locale('ja')], supported);
    expect(r.languageCode, base.languageCode);
  });

  test('en_GB still finds the app texts', () {
    expect(AppLocalizations.delegate.isSupported(const Locale('en', 'GB')),
        isTrue);
  });
}
