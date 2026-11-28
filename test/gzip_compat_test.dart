// Drive files (sync logbook, backups) were gzipped with dart:io; the app now
// uses package:archive (dart:io's gzip doesn't exist on web). Both must read
// each other's output.
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/services/backup_util.dart';

void main() {
  final rnd = Random(7);
  final raw = List<int>.generate(200000, (i) => i % 7 == 0 ? rnd.nextInt(256) : i % 251);

  test('dart:io gzip (old uploads) -> archive decode', () {
    expect(GZipDecoder().decodeBytes(gzip.encode(raw)), raw);
    expect(maybeGunzip(gzip.encode(raw)), raw);
  });

  test('archive gzip (new uploads) -> dart:io decode (older app versions)', () {
    expect(gzip.decode(GZipEncoder().encodeBytes(raw)), raw);
  });
}
