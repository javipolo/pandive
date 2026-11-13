/// Servicio de ordenador de buceo (puente a libdivecomputer vía MethodChannel).
/// Capacidad, escaneo BLE y descarga de inmersiones.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pandive/core/models/models.dart';

/// Un dispositivo BLE encontrado durante el escaneo.
class ScannedDevice {
  final String name;
  final String id; // dirección MAC
  final int rssi;
  final bool likely; // parece un ordenador de buceo (por el nombre)

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

  /// Progreso de descarga en curso (0.0–1.0). Suscríbete antes de llamar a
  /// [download] para no perder eventos.
  Stream<double> progress() {
    return _progressChannel.receiveBroadcastStream().map((e) {
      final m = e as Map;
      final cur = (m['current'] as num?)?.toDouble() ?? 0;
      final max = (m['maximum'] as num?)?.toDouble() ?? 0;
      return max > 0 ? (cur / max).clamp(0.0, 1.0) : 0.0;
    });
  }

  /// Nº de modelos de ordenador soportados por libdivecomputer.
  Future<int> supportedCount() async {
    final n = await _channel.invokeMethod<int>('supportedCount');
    return n ?? 0;
  }

  /// Lista "Vendor Product" de modelos soportados.
  Future<List<String>> supportedList() async {
    final s = await _channel.invokeMethod<String>('supportedList') ?? '';
    return s
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Pide los permisos de Bluetooth necesarios. Devuelve true si concedidos.
  /// En Android 12+ usa BLUETOOTH_SCAN/CONNECT; en <=11, localización.
  Future<bool> requestBlePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // necesario en Android <= 11
    ].request();
    // En 12+ basta con scan+connect; location puede quedar denegado y no pasa nada.
    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];
    if (scan != null && connect != null) {
      return scan.isGranted && connect.isGranted;
    }
    // Fallback (plataformas antiguas): localización concedida.
    return statuses[Permission.locationWhenInUse]?.isGranted ?? false;
  }

  /// Escaneo BLE en vivo. Cada evento es un dispositivo encontrado (puede
  /// repetirse; deduplicar por [ScannedDevice.id] en el consumidor).
  Stream<ScannedDevice> scan() {
    return _scanChannel
        .receiveBroadcastStream()
        .map((e) => ScannedDevice.fromMap(e as Map));
  }

  /// Conecta por BLE a [address] y descarga las inmersiones del modelo
  /// [vendor]/[product]. Bloqueante en nativo; puede tardar.
  Future<DownloadResult> download({
    required String vendor,
    required String product,
    required String address,
    String fingerprint = '',
    int maxDives = 0, // 0 = todas; 1 = solo la más reciente (fingerprint)
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

/// Mapea el nombre anunciado por BLE al (vendor, product) de libdivecomputer.
/// Cobertura inicial de los modelos objetivo; ampliable.
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
