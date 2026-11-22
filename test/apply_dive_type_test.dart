import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/logic/apply_dive_type.dart';

void main() {
  const empty = Cylinder(size: 12); // sin presiones
  const used = Cylinder(size: 15, pressureStart: 200, pressureEnd: 50);
  const typeA = Cylinder(size: 7, name: 'L');
  const typeB = Cylinder(size: 7, name: 'R');

  test('tipo con botellas: descarta vacías, conserva con presiones, añade tipo', () {
    final r = applyDiveTypeTanks([empty, used], [typeA, typeB]);
    expect(r.map((c) => c.name ?? c.size.toString()),
        ['15.0', 'L', 'R']); // empty fuera, used primero, luego tipo
    expect(r.length, 3);
  });

  test('solo botella vacía + tipo: queda solo el tipo', () {
    final r = applyDiveTypeTanks([empty], [typeA]);
    expect(r, [typeA]);
  });

  test('tipo sin botellas: no toca nada', () {
    final r = applyDiveTypeTanks([empty, used], const []);
    expect(r, [empty, used]);
  });

  test('tankHasPressure: solo con entrada o salida > 0', () {
    expect(tankHasPressure(empty), isFalse);
    expect(tankHasPressure(used), isTrue);
    expect(tankHasPressure(const Cylinder(pressureStart: 200)), isTrue);
    expect(tankHasPressure(const Cylinder(pressureEnd: 50)), isTrue);
  });
}
