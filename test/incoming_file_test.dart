// detectIncomingKind: guesses a shared file's kind from its first bytes.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/features/settings/logic/import_from_file.dart';

void main() {
  IncomingKind k(String s) => detectIncomingKind(utf8.encode(s));

  test('SQLite header is a .ddb', () {
    expect(detectIncomingKind([...utf8.encode('SQLite format 3'), 0, 1, 2]),
        IncomingKind.ddb);
  });
  test('XML is Subsurface, with or without BOM and leading spaces', () {
    expect(k('<?xml version="1.0"?><divelog>'), IncomingKind.subsurface);
    expect(k('﻿  \n<divelog>'), IncomingKind.subsurface);
  });
  test('JSON array or object is the sites file', () {
    expect(k('[{"name":"Medes"}]'), IncomingKind.sitesJson);
    expect(k('\n {"sites":[]}'), IncomingKind.sitesJson);
  });
  test('anything else is the SSI CSV', () {
    expect(k('Dive No.;Date;Time\n1;01.01.2024;10:00'), IncomingKind.ssiCsv);
    expect(detectIncomingKind([]), IncomingKind.ssiCsv);
  });
}
