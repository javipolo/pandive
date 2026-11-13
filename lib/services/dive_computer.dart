/// Servicio de ordenador de buceo (puente a libdivecomputer vía MethodChannel).
/// Fase 2, hito A: consultas de capacidad. Escaneo/descarga llegan en hitos B-D.
library;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
}
