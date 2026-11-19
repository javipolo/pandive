import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/gas_plan.dart';

void main() {
  group('computeGasPlan', () {
    test('gas needed = rmv * time * ata', () {
      // RMV 20 l/min, 30 m (4 ata), 40 min => 20*40*4 = 3200 L
      final p = computeGasPlan(
        rmv: 20,
        avgDepthM: 30,
        timeMin: 40,
        totalLitres: 24, // bibo 2x12
        startBar: 200,
        reserveBar: 35,
      )!;
      expect(p.gasNeededL, closeTo(3200, 0.01));
      // ΔP = 3200 / 24 = 133.3 bar
      expect(p.deltaBar, closeTo(133.33, 0.1));
      // end = 200 - 133.3 = 66.7 bar, por encima de 35 => ok
      expect(p.endBar, closeTo(66.67, 0.1));
      expect(p.ok, isTrue);
      expect(p.marginBar, closeTo(31.67, 0.1));
    });

    test('flags insufficient gas (end below reserve)', () {
      // Misma demanda con config más pequeña: mono 12 L
      final p = computeGasPlan(
        rmv: 20,
        avgDepthM: 30,
        timeMin: 40,
        totalLitres: 12,
        startBar: 200,
        reserveBar: 35,
      )!;
      // ΔP = 3200/12 = 266.7 => end negativo => no llega
      expect(p.endBar, lessThan(35));
      expect(p.ok, isFalse);
      expect(p.marginBar, lessThan(0));
    });

    test('max time respects reserve', () {
      // usable = (200-35)*24 = 3960 L ; /(20*4) = 49.5 min
      final p = computeGasPlan(
        rmv: 20,
        avgDepthM: 30,
        timeMin: 40,
        totalLitres: 24,
        startBar: 200,
        reserveBar: 35,
      )!;
      expect(p.maxTimeMin, closeTo(49.5, 0.1));
    });

    test('returns null when inputs incomplete or non-positive', () {
      expect(
          computeGasPlan(
              rmv: null,
              avgDepthM: 30,
              timeMin: 40,
              totalLitres: 24,
              startBar: 200,
              reserveBar: 35),
          isNull);
      expect(
          computeGasPlan(
              rmv: 20,
              avgDepthM: 0,
              timeMin: 40,
              totalLitres: 24,
              startBar: 200,
              reserveBar: 35),
          isNull);
      expect(
          computeGasPlan(
              rmv: 20,
              avgDepthM: 30,
              timeMin: 40,
              totalLitres: 0,
              startBar: 200,
              reserveBar: 35),
          isNull);
    });
  });
}
