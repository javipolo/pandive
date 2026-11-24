/// Tipo de red actual, para las opciones "solo con WiFi" de backup y sync.
library;

import 'package:connectivity_plus/connectivity_plus.dart';

/// ¿Estamos en una red sin coste (WiFi o cable)? Si no se puede saber,
/// true (no bloquear por un fallo del detector).
Future<bool> onUnmeteredNetwork() async {
  try {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return true;
  }
}
