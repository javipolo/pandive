/// "Human" date and time: "Today 17:12", "Yesterday 21:23" and, for the rest, the
/// full date with the given pattern.
library;

import 'package:intl/intl.dart';

import 'package:pandive/l10n/app_localizations.dart';

/// [dt] (local time) as "Today HH:mm" / "Yesterday HH:mm", or with [pattern] if it's
/// another day. [now] only for tests.
String relativeDateTime(DateTime dt, AppLocalizations t, String locale,
    {String pattern = 'd MMM yyyy, HH:mm', DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final time = DateFormat('HH:mm', locale).format(dt);
  // By calendar date (not "< 24 h ago"); robust to DST changes.
  if (day == today) return t.todayAt(time);
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return t.yesterdayAt(time);
  }
  return DateFormat(pattern, locale).format(dt);
}
