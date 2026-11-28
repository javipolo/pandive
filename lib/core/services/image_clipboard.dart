/// Copy a PNG image to the clipboard. Flutter only copies text: on Linux
/// the native runner does it (channel `pandive/clipboard`, GTK).
library;


import 'package:flutter/services.dart';
import '../platform.dart';

const _channel = MethodChannel('pandive/clipboard');

/// Can images be copied on this platform?
bool get canCopyImages => isLinux;

/// Copies [png] to the clipboard. Returns false if it couldn't.
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
