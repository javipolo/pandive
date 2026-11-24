/// Fecha y hora "humanas": "Hoy 17:12", "Ayer 21:23" y, para el resto, la
/// fecha completa con el patrón que se pase.
library;

import 'package:intl/intl.dart';

import 'package:pandive/l10n/app_localizations.dart';

/// [dt] (hora local) como "Hoy HH:mm" / "Ayer HH:mm", o con [pattern] si es
/// de otro día. [now] solo para tests.
String relativeDateTime(DateTime dt, AppLocalizations t, String locale,
    {String pattern = 'd MMM yyyy, HH:mm', DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final time = DateFormat('HH:mm', locale).format(dt);
  // Por fecha de calendario (no "hace < 24 h"); robusto al cambio de hora.
  if (day == today) return t.todayAt(time);
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return t.yesterdayAt(time);
  }
  return DateFormat(pattern, locale).format(dt);
}
