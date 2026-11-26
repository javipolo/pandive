import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/logic/apply_dive_type.dart';

void main() {
  const empty = Cylinder(size: 12); // no pressures
  const used = Cylinder(size: 15, pressureStart: 200, pressureEnd: 50);
  const typeA = Cylinder(size: 7, name: 'L');
  const typeB = Cylinder(size: 7, name: 'R');

  test('tipo con botellas: descarta vacías, conserva con presiones, añade tipo', () {
    final r = applyDiveTypeTanks([empty, used], [typeA, typeB]);
    expect(r.map((c) => c.name ?? c.size.toString()),
        ['15.0', 'L', 'R']); // empty out, used first, then type
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

  test('botellas ya rellenas del tipo: no se duplican', () {
    const filled = Cylinder(
        size: 11.1,
        pressureStart: 200,
        pressureEnd: 60,
        material: TankMaterial.aluminium);
    const side = Cylinder(size: 11.1, material: TankMaterial.aluminium);
    final r = applyDiveTypeTanks([filled, filled], [side, side]);
    expect(r, [filled, filled]);
  });

  test('solo cubre las que faltan (1 rellena + tipo de 2 → 2)', () {
    const filled = Cylinder(size: 11.1, pressureStart: 200);
    const side = Cylinder(size: 11.1, material: TankMaterial.aluminium);
    final r = applyDiveTypeTanks([filled], [side, side]);
    expect(r, [filled, side]);
  });

  test('distinto material o tamaño: se añade', () {
    const steel =
        Cylinder(size: 11.1, pressureStart: 200, material: TankMaterial.steel);
    const alu = Cylinder(size: 11.1, material: TankMaterial.aluminium);
    expect(applyDiveTypeTanks([steel], [alu]), [steel, alu]);
    expect(applyDiveTypeTanks([used], [typeA]), [used, typeA]);
  });

  test('tankHasPressure: solo con entrada o salida > 0', () {
    expect(tankHasPressure(empty), isFalse);
    expect(tankHasPressure(used), isTrue);
    expect(tankHasPressure(const Cylinder(pressureStart: 200)), isTrue);
    expect(tankHasPressure(const Cylinder(pressureEnd: 50)), isTrue);
  });
}
