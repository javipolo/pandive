/// Copiar una imagen PNG al portapapeles. Flutter solo copia texto: en Linux
/// lo hace el runner nativo (canal `pandive/clipboard`, GTK).
library;

import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('pandive/clipboard');

/// ¿Se pueden copiar imágenes en esta plataforma?
bool get canCopyImages => Platform.isLinux;

/// Copia [png] al portapapeles. Devuelve false si no se pudo.
Future<bool> copyPngToClipboard(Uint8List png) async {
  if (!canCopyImages) return false;
  try {
    return await _channel.invokeMethod<bool>('copyImage', png) ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
