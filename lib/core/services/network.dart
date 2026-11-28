/// Current network type, for the "WiFi only" backup and sync options.
library;

import 'package:connectivity_plus/connectivity_plus.dart';

import '../platform.dart';

/// Are we on an unmetered network (WiFi or cable)? If it can't be known,
/// true (don't block because of a detector failure). Browsers can't tell
/// reliably either: always true on web.
Future<bool> onUnmeteredNetwork() async {
  if (isWeb) return true;
  try {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return true;
  }
}
