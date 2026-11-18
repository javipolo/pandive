/// Exporta el logbook al XML de Subsurface (.ssrf). Formato `divelog version=3`.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll("'", '&apos;')
    .replaceAll('"', '&quot;');

String _p2(int v) => v.toString().padLeft(2, '0');
String _mmss(int sec) => '${sec ~/ 60}:${_p2(sec % 60)} min';
String _siteId(int id) => id.toRadixString(16).padLeft(8, '0');

/// Construye el XML Subsurface con todas las inmersiones del owner.
String buildSubsurfaceXml(DivemateDb db) {
  final dives = db.listDives();
  final sites = <int, DiveSite>{};
  for (final d in dives) {
    final pid = d.placeId;
    if (pid != null && !sites.containsKey(pid)) {
      final s = db.getSite(pid);
      if (s != null) sites[pid] = s;
    }
  }
  final b = StringBuffer()
    ..writeln("<divelog program='pandive' version='3'>")
    ..writeln('<settings>')
    ..writeln('</settings>')
    ..writeln('<divesites>');
  for (final s in sites.values) {
    final gps = (s.lat != null && s.lon != null) ? " gps='${s.lat} ${s.lon}'" : '';
    b.writeln("<site uuid='${_siteId(s.id)}' name='${_esc(s.name ?? '')}'$gps/>");
  }
  b
    ..writeln('</divesites>')
    ..writeln('<dives>');
  for (final d in dives) {
    _writeDive(b, db, d);
  }
  b
    ..writeln('</dives>')
    ..writeln('</divelog>');
  return b.toString();
}

void _writeDive(StringBuffer b, DivemateDb db, Dive d) {
  final dt = d.date;
  final attrs = StringBuffer();
  if (d.number != null) attrs.write(" number='${d.number}'");
  final sac = db.diveSac(d.id);
  if (sac != null) attrs.write(" sac='${sac.toStringAsFixed(3)} l/min'");
  if (d.placeId != null) attrs.write(" divesiteid='${_siteId(d.placeId!)}'");
  final tags = db.tagsForDive(d.id).map((t) => t.name).join(', ');
  if (tags.isNotEmpty) attrs.write(" tags='${_esc(tags)}'");
  if (dt != null) {
    attrs.write(" date='${dt.year}-${_p2(dt.month)}-${_p2(dt.day)}'");
    attrs.write(" time='${_p2(dt.hour)}:${_p2(dt.minute)}:00'");
  }
  if (d.durationMin != null) {
    attrs.write(" duration='${_mmss((d.durationMin! * 60).round())}'");
  }
  b.writeln('<dive${attrs.toString()}>');
  for (final bud in db.diveBuddies(d.id)) {
    b.writeln('  <buddy>${_esc(bud.name)}</buddy>');
  }
  for (final c in db.cylinders(d.id)) {
    _writeCylinder(b, c);
  }
  _writeComputer(b, db, d);
  if (d.comments != null) b.writeln('  <notes>${_esc(d.comments!)}</notes>');
  b.writeln('</dive>');
}

void _writeCylinder(StringBuffer b, Cylinder c) {
  final a = StringBuffer();
  if (c.size != null) a.write(" size='${c.size!.toStringAsFixed(1)} l'");
  if (c.o2 != null && c.o2! > 0) a.write(" o2='${c.o2!.toStringAsFixed(1)}%'");
  if (c.he != null && c.he! > 0) a.write(" he='${c.he!.toStringAsFixed(1)}%'");
  if (c.pressureStart != null) {
    a.write(" start='${c.pressureStart!.toStringAsFixed(1)} bar'");
  }
  if (c.pressureEnd != null) {
    a.write(" end='${c.pressureEnd!.toStringAsFixed(1)} bar'");
  }
  if (a.isNotEmpty) b.writeln('  <cylinder${a.toString()} />');
}

void _writeComputer(StringBuffer b, DivemateDb db, Dive d) {
  final p = db.diveProfile(d.id);
  final model = _esc(d.computer ?? 'PanDive');
  b.writeln("  <divecomputer model='$model'>");
  if (d.maxDepth != null) {
    final mean = d.avgDepth != null ? " mean='${d.avgDepth!.toStringAsFixed(2)} m'" : '';
    b.writeln("  <depth max='${d.maxDepth!.toStringAsFixed(2)} m'$mean />");
  }
  if (d.waterTemp != null) {
    b.writeln("  <temperature water='${d.waterTemp!.toStringAsFixed(1)} C' />");
  }
  if (p != null && !p.isEmpty) {
    final iv = p.intervalSeconds;
    for (var i = 0; i < p.depths.length; i++) {
      final t = p.temps[i];
      final temp = t != null ? " temp='${t.toStringAsFixed(1)} C'" : '';
      b.writeln("  <sample time='${_mmss(i * iv)}' "
          "depth='${p.depths[i].toStringAsFixed(1)} m'$temp />");
    }
  }
  b.writeln('  </divecomputer>');
}
