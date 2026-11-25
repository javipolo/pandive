// "Today 17:12" / "Yesterday 21:23" / full date in the backups list.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pandive/core/text/relative_date.dart';
import 'package:pandive/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  final t = lookupAppLocalizations(const Locale('es'));
  final now = DateTime(2026, 11, 24, 18, 0);
  String f(DateTime d, [DateTime? n]) =>
      relativeDateTime(d, t, 'es', now: n ?? now);

  test('hoy, ayer y otros días', () {
    expect(f(DateTime(2026, 11, 24, 17, 12)), 'Hoy 17:12');
    expect(f(DateTime(2026, 11, 24, 0, 5)), 'Hoy 00:05');
    expect(f(DateTime(2026, 11, 23, 21, 23)), 'Ayer 21:23');
    expect(f(DateTime(2026, 11, 22, 23, 59)), startsWith('22 nov'));
  });

  test('ayer a través de cambio de mes y de año', () {
    expect(f(DateTime(2026, 12, 31, 22, 0), DateTime(2027, 1, 1, 9)),
        'Ayer 22:00');
    expect(f(DateTime(2026, 2, 28, 10, 0), DateTime(2026, 3, 1, 9)),
        'Ayer 10:00');
  });
}
