// Smoke test básico de Pandive.
import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';

void main() {
  test('gasLabel identifica mezclas', () {
    expect(const Cylinder(o2: 21).gasLabel, 'Aire');
    expect(const Cylinder(o2: 32).gasLabel, 'Nitrox EAN32');
    expect(const Cylinder(o2: 18, he: 45).gasLabel, 'Trimix 18/45');
    expect(const Cylinder().gasLabel, 'Aire');
  });
}
