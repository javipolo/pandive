/// Importa inmersiones del XML de Subsurface (.ssrf) al logbook. Inverso de
/// `subsurface_export.dart`. Devuelve cuántas inmersiones nuevas se añadieron.
library;

import 'dart:isolate';

import 'package:xml/xml.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Primer número de un valor con unidad: "12.3 m" -> 12.3, "32.0%" -> 32.0.
double? _num(String? s) {
  if (s == null) return null;
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(0)!);
}

XmlElement? _first(Iterable<XmlElement> e) => e.isEmpty ? null : e.first;

/// "mm:ss" (o "h:mm:ss") -> segundos.
int _secs(String? s) {
  if (s == null) return 0;
  final parts = s.trim().split(' ').first.split(':');
  var sec = 0;
  for (final p in parts) {
    sec = sec * 60 + (int.tryParse(p) ?? 0);
  }
  return sec;
}

// Analiza el XML (MB con miles de muestras) en otro isolate para no
// bloquear la UI. Función aparte: el cierre solo debe capturar [xml] (si
// capturase la DB, no se podría enviar al isolate).
Future<XmlDocument> _parseOffThread(String xml) =>
    Isolate.run(() => XmlDocument.parse(xml));

Future<int> importSubsurfaceXml(DivemateDb db, String xml,
    {void Function(int done, int total)? onProgress}) async {
  final doc = await _parseOffThread(xml);
  final sites = <String, ({String name, double? lat, double? lon})>{};
  for (final s in doc.findAllElements('site')) {
    final uuid = s.getAttribute('uuid');
    if (uuid == null) continue;
    final gps = s.getAttribute('gps')?.trim().split(RegExp(r'\s+'));
    sites[uuid] = (
      name: s.getAttribute('name') ?? '',
      lat: (gps != null && gps.length == 2) ? double.tryParse(gps[0]) : null,
      lon: (gps != null && gps.length == 2) ? double.tryParse(gps[1]) : null,
    );
  }

  final dives = doc.findAllElements('dive').toList();
  var added = 0;
  // Por bloques: una transacción cada uno (mucho más rápido que un commit por
  // sentencia) y ceder el hilo entre bloques para que la barra avance y
  // Android no dé "la app no responde".
  const chunk = 20;
  for (var i = 0; i < dives.length; i += chunk) {
    final part = dives.sublist(i, (i + chunk).clamp(0, dives.length));
    added += db.inTransaction(
        () => part.where((d) => _importOne(db, d, sites)).length);
    onProgress?.call(i + part.length, dives.length);
    await Future<void>.delayed(Duration.zero);
  }
  if (added > 0) db.autoRenumber();
  return added;
}

bool _importOne(DivemateDb db, XmlElement dive,
    Map<String, ({String name, double? lat, double? lon})> sites) {
  final date = dive.getAttribute('date');
  final time = dive.getAttribute('time') ?? '00:00:00';
  if (date == null) return false;
  final dt = DateTime.tryParse('${date}T$time');
  if (dt == null) return false;

  final site = sites[dive.getAttribute('divesiteid')];
  final dur = dive.getAttribute('duration');
  final tags = (dive.getAttribute('tags') ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final buddies = dive
      .findElements('buddy')
      .expand((b) => b.innerText.split(','))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final notes = dive.findElements('notes').map((e) => e.innerText).join('\n');

  final cylinders = [
    for (final c in dive.findElements('cylinder'))
      Cylinder(
        size: _num(c.getAttribute('size')),
        o2: _num(c.getAttribute('o2')),
        he: _num(c.getAttribute('he')),
        pressureStart: _num(c.getAttribute('start')),
        pressureEnd: _num(c.getAttribute('end')),
      ),
  ];

  final dc = _first(dive.findElements('divecomputer'));
  final depth = _first(dc?.findElements('depth') ?? const <XmlElement>[]);
  final samples = [
    for (final s in dc?.findElements('sample') ?? const <XmlElement>[])
      DiveSample(_secs(s.getAttribute('time')) * 1000,
          _num(s.getAttribute('depth')) ?? 0, _num(s.getAttribute('temp'))),
  ];

  return db.importExternalDive(
    dateTime: dt,
    placeName: site?.name,
    lat: site?.lat,
    lon: site?.lon,
    comments: notes.isEmpty ? null : notes,
    buddies: buddies,
    tagNames: tags,
    maxDepth: _num(depth?.getAttribute('max')),
    avgDepth: _num(depth?.getAttribute('mean')),
    durationMin: dur == null ? null : _secs(dur) / 60.0,
    waterTemp: _num(_first(dc?.findElements('temperature') ?? const <XmlElement>[])?.getAttribute('water')),
    computer: dc?.getAttribute('model'),
    o2: cylinders.isNotEmpty ? cylinders.first.o2 : null,
    samples: samples,
    cylinders: cylinders,
  );
}
