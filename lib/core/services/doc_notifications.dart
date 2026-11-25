/// Local document expiry notifications: 30/7/1 days before and on the
/// day itself. Reschedules all from scratch on each change. Only asks for permission if
/// some document has an expiry date (otherwise it doesn't bother the user).
/// The payload of each notification is the document id, so that tapping it
/// opens that document in the app ([tappedDocId] / [consumeNotificationLaunch]).
/// Android only: on Linux there are no scheduled notifications (zonedSchedule).
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/l10n/app_localizations.dart';

const _offsets = [30, 7, 1, 0]; // days before expiry (0 = same day)

final _plugin = FlutterLocalNotificationsPlugin();
bool _inited = false;

/// Document id of the last notification tapped with the app open (or in
/// the background). HomeScreen listens to it to open that document.
final ValueNotifier<int?> tappedDocId = ValueNotifier<int?>(null);

void _onTap(NotificationResponse r) {
  final id = int.tryParse(r.payload ?? '');
  if (id != null) tappedDocId.value = id;
}

/// If the app was opened (cold) by tapping a notification, returns the
/// document id only once; otherwise null.
Future<int?> consumeNotificationLaunch() async {
  if (!Platform.isAndroid) return null;
  await _init();
  final d = await _plugin.getNotificationAppLaunchDetails();
  if (d?.didNotificationLaunchApp != true) return null;
  return int.tryParse(d!.notificationResponse?.payload ?? '');
}

Future<void> _init() async {
  if (_inited) return;
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {/* keep UTC by default */}
  await _plugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_panda')),
    onDidReceiveNotificationResponse: _onTap,
  );
  _inited = true;
}

/// Reschedules all expiry notifications from the current state.
Future<void> syncDocNotifications(DivemateDb db, AppLocalizations t) async {
  if (!Platform.isAndroid) return;
  await _init();
  await _plugin.cancelAll();

  final docs = db
      .listDocuments()
      .where((d) => d.expires && d.expiryDate != null)
      .toList();
  if (docs.isEmpty) return; // no expiries: don't ask for permission

  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  final granted = await android?.requestNotificationsPermission() ?? false;
  if (!granted) return;
  await android?.requestExactAlarmsPermission();

  final details = NotificationDetails(
    android: AndroidNotificationDetails('doc_expiry', t.docNotifTitle,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_panda',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')),
  );
  final now = tz.TZDateTime.now(tz.local);

  for (final d in docs) {
    final e = d.expiryDate!;
    for (var k = 0; k < _offsets.length; k++) {
      final when = tz.TZDateTime(tz.local, e.year, e.month, e.day, 21)
          .subtract(Duration(days: _offsets[k]));
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        d.id * 10 + k,
        t.docNotifTitle,
        t.docNotifBody(_offsets[k], d.title),
        when,
        details,
        payload: '${d.id}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
