/// Platform checks that are safe in the browser (`dart:io`'s `Platform`
/// throws there). Use these instead of `Platform.isX`.
library;

import 'package:flutter/foundation.dart';

/// Running as a web app (browser).
bool get isWeb => kIsWeb;

/// Android app.
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Linux desktop app.
bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
