/// Dive computer service (bridge to libdivecomputer via MethodChannel).
/// Capability, BLE scan and dive download.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pandive/core/models/models.dart';

/// A BLE device found during the scan.
class ScannedDevice {
  final String name;
  final String id; // MAC address
  final int rssi;
  final bool likely; // looks like a dive computer (by name)

  const ScannedDevice({
    required this.name,
    required this.id,
    required this.rssi,
    required this.likely,
  });

  factory ScannedDevice.fromMap(Map<dynamic, dynamic> m) => ScannedDevice(
        name: (m['name'] ?? '') as String,
        id: (m['id'] ?? '') as String,
        rssi: (m['rssi'] ?? 0) as int,
        likely: (m['likely'] ?? false) as bool,
      );
}

class DiveComputerService {
  static const _channel = MethodChannel('pandive/dc');
  static const _scanChannel = EventChannel('pandive/dc/scan');
  static const _progressChannel = EventChannel('pandive/dc/progress');

  /// Progress of the ongoing download (0.0–1.0). Subscribe before calling
  /// [download] so as not to miss events.
  Stream<double> progress() {
    return _progressChannel.receiveBroadcastStream().map((e) {
      final m = e as Map;
      final cur = (m['current'] as num?)?.toDouble() ?? 0;
      final max = (m['maximum'] as num?)?.toDouble() ?? 0;
      return max > 0 ? (cur / max).clamp(0.0, 1.0) : 0.0;
    });
  }

  /// Resolves (vendor, product) for a BLE name using libdivecomputer's own
  /// matcher (covers all models). Fallback: local list.
  Future<(String, String)?> matchModel(String name) async {
    try {
      final s = await _channel.invokeMethod<String>('matchName', {'name': name});
      if (s != null && s.contains('\t')) {
        final parts = s.split('\t');
        if (parts[0].isNotEmpty && parts[1].isNotEmpty) {
          return (parts[0], parts[1]);
        }
      }
    } catch (_) {/* native not available */}
    return modelForDeviceName(name);
  }

  /// Is Bluetooth on (phone or PC adapter)?
  Future<bool> isBluetoothOn() async =>
      await _channel.invokeMethod<bool>('btEnabled') ?? false;

  /// Turns Bluetooth on (Android: system dialog; Linux: BlueZ).
  Future<void> requestEnableBluetooth() =>
      _channel.invokeMethod<void>('enableBt');

  /// Requests the needed Bluetooth permissions. Returns true if granted.
  /// On Android 12+ uses BLUETOOTH_SCAN/CONNECT; on <=11, location.
  /// On Linux there are no app permissions: BlueZ decides via D-Bus/polkit.
  Future<bool> requestBlePermissions() async {
    if (Platform.isLinux) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // needed on Android <= 11
    ].request();
    // On 12+ scan+connect is enough; location may stay denied and that's fine.
    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];
    if (scan != null && connect != null) {
      return scan.isGranted && connect.isGranted;
    }
    // Fallback (old platforms): location granted.
    return statuses[Permission.locationWhenInUse]?.isGranted ?? false;
  }

  /// Live BLE scan. Each event is a device found (may
  /// repeat; dedupe by [ScannedDevice.id] in the consumer).
  Stream<ScannedDevice> scan() {
    return _scanChannel
        .receiveBroadcastStream()
        .map((e) => ScannedDevice.fromMap(e as Map));
  }

  /// Connects over BLE to [address] and downloads the dives of model
  /// [vendor]/[product]. Blocking on the native side; may take a while.
  Future<DownloadResult> download({
    required String vendor,
    required String product,
    required String address,
    String fingerprint = '',
    int maxDives = 0, // 0 = all; 1 = only the most recent (fingerprint)
  }) async {
    final raw = await _channel.invokeMethod<String>('download', {
      'vendor': vendor,
      'product': product,
      'address': address,
      'fingerprint': fingerprint,
      'maxDives': maxDives,
    });
    final j = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
    if (j['error'] != null) {
      return DownloadResult(error: j['error'] as String);
    }
    final dives = [
      for (final d in (j['dives'] as List? ?? []))
        DownloadedDive.fromJson(d as Map<String, dynamic>),
    ];
    return DownloadResult(dives: dives);
  }
}

/// Maps the BLE advertised name to libdivecomputer's (vendor, product).
/// Initial coverage of the target models; extensible.
(String vendor, String product)? modelForDeviceName(String name) {
  final n = name.toLowerCase();
  if (n.contains('peregrine')) return ('Shearwater', 'Peregrine');
  if (n.contains('perdix')) return ('Shearwater', 'Perdix');
  if (n.contains('petrel')) return ('Shearwater', 'Petrel 2');
  if (n.contains('teric')) return ('Shearwater', 'Teric');
  if (n.contains('tern')) return ('Shearwater', 'Tern');
  if (n.contains('puck')) return ('Mares', 'Puck 4');
  return null;
}
