/// Locale resolution: English runs as British English (en_GB) so dates read
/// day/month/year and times are 24 h everywhere, including the system date
/// and time pickers (US English would give MM/DD/YYYY and AM/PM). The app's
/// own texts are the same: AppLocalizations only looks at the language.
library;

import 'package:material_ui/material_ui.dart';

/// Use as `MaterialApp.localeListResolutionCallback`.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  final l = basicLocaleListResolution(preferred, supported);
  return l.languageCode == 'en' ? const Locale('en', 'GB') : l;
}
