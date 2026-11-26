/// Incoming file (open with / share to PanDive): .ddb, SSI CSV, sites JSON
/// or .ssrf; HomeScreen routes it by content. The native side copies
/// the content to a temp file and exposes its path. Android only (intents); on
/// other platforms there is no incoming file.
library;

import 'dart:io';

import 'package:flutter/services.dart';

class OpenedFile {
  static const _ch = MethodChannel('pandive/open');
  static const _events = EventChannel('pandive/open/events');

  /// Path of the file the app was launched with (and clears it), or null.
  static Future<String?> consume() async =>
      Platform.isAndroid ? _ch.invokeMethod<String>('consume') : null;

  /// Paths of files opened while the app was already running.
  static Stream<String> events() => Platform.isAndroid
      ? _events.receiveBroadcastStream().map((e) => e as String)
      : const Stream.empty();
}
