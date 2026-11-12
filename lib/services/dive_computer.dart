/// Servicio de ordenador de buceo (puente a libdivecomputer vía MethodChannel).
/// Fase 2, hito A: consultas de capacidad. Escaneo/descarga llegan en hitos B-D.
library;

import 'package:flutter/services.dart';

class DiveComputerService {
  static const _channel = MethodChannel('pandive/dc');

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
}
