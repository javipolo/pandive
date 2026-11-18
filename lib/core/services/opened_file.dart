/// Fichero .ddb entrante (abrir con / compartir hacia PanDive). El nativo copia
/// el contenido a un temporal y expone su ruta.
library;

import 'package:flutter/services.dart';

class OpenedFile {
  static const _ch = MethodChannel('pandive/open');
  static const _events = EventChannel('pandive/open/events');

  /// Ruta del .ddb con el que se lanzó la app (y la limpia), o null.
  static Future<String?> consume() => _ch.invokeMethod<String>('consume');

  /// Rutas de .ddb abiertos mientras la app ya estaba en marcha.
  static Stream<String> events() =>
      _events.receiveBroadcastStream().map((e) => e as String);
}
