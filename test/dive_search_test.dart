import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';
import 'package:pandive/features/dives/logic/dive_search.dart';

void main() {
  test('foldContains ignora acentos y mayúsculas', () {
    expect(foldContains('Tomás', 'tomas'), isTrue);
    expect(foldContains('tomas', 'Tomás'), isTrue);
    expect(foldContains('Niño', 'nino'), isTrue);
    expect(foldContains('Pedro', 'tomas'), isFalse);
  });

  test('diveMatches encuentra compañero con acento buscando sin él', () {
    const d = Dive(id: 1, buddy: 'Tomás Pérez', number: 42);
    expect(diveMatches(d, 'tomas'), isTrue);
    expect(diveMatches(d, 'perez'), isTrue);
    expect(diveMatches(d, '42'), isTrue); // by number
    expect(diveMatches(d, 'juan'), isFalse);
  });
}
