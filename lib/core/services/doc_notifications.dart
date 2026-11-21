/// Notificaciones locales de caducidad de documentos: 30/7/1 días antes y el
/// mismo día. Reprograma todas desde cero en cada cambio. Solo pide permiso si
/// hay algún documento con fecha de caducidad (si no, no molesta al usuario).
/// El payload de cada notificación es el id del documento, para que al pulsarla
/// la app abra ese documento ([tappedDocId] / [consumeNotificationLaunch]).
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/l10n/app_localizations.dart';

const _offsets = [30, 7, 1, 0]; // días antes de caducar (0 = el mismo día)

final _plugin = FlutterLocalNotificationsPlugin();
bool _inited = false;

/// Id del documento de la última notificación pulsada con la app abierta (o en
/// segundo plano). Lo escucha HomeScreen para abrir ese documento.
final ValueNotifier<int?> tappedDocId = ValueNotifier<int?>(null);

void _onTap(NotificationResponse r) {
  final id = int.tryParse(r.payload ?? '');
  if (id != null) tappedDocId.value = id;
}

/// Si la app se abrió (en frío) al pulsar una notificación, devuelve el id del
/// documento una sola vez; si no, null.
Future<int?> consumeNotificationLaunch() async {
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
  } catch (_) {/* deja UTC por defecto */}
  await _plugin.initialize(
    const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_panda')),
    onDidReceiveNotificationResponse: _onTap,
  );
  _inited = true;
}

/// Reprograma todas las notificaciones de caducidad a partir del estado actual.
Future<void> syncDocNotifications(DivemateDb db, AppLocalizations t) async {
  await _init();
  await _plugin.cancelAll();

  final docs = db
      .listDocuments()
      .where((d) => d.expires && d.expiryDate != null)
      .toList();
  if (docs.isEmpty) return; // sin caducidades: no pedir permiso

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
