import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/gas_plan.dart';

void main() {
  group('computeGasPlan', () {
    test('single cylinder, fixed reserve', () {
      // RMV 20, 30 m (4 ata), 40 min => 3200 L. 24 L @ 200 bar, reserve 35.
      final p = computeGasPlan(
        rmv: 20,
        avgDepthM: 30,
        timeMin: 40,
        cylinders: const [PlanCylinder(24)],
        startBar: 200,
        rule: ReserveRule.bar35,
      )!;
      expect(p.gasNeededL, closeTo(3200, 0.01));
      expect(p.reserveThresholdBar, closeTo(35, 0.01));
      expect(p.endReserveBar, closeTo(66.67, 0.1)); // (4800-3200)/24
      expect(p.ok, isTrue);
      expect(p.hasStages, isFalse);
      expect(p.maxTimeMin, closeTo(49.5, 0.1)); // (4800-840)/(20*4)
    });

    test('mixed sizes with a stage, thirds counts all gas', () {
      // 2x11.1 reserve + 7 stage, 200 bar. Gas: 15*40*5 = 3000 L.
      final p = computeGasPlan(
        rmv: 15,
        avgDepthM: 40, // 5 ata
        timeMin: 40,
        cylinders: const [
          PlanCylinder(11.1),
          PlanCylinder(11.1),
          PlanCylinder(7, keepsReserve: false),
        ],
        startBar: 200,
        rule: ReserveRule.thirds,
      )!;
      expect(p.hasStages, isTrue);
      // totalGas = 29.2*200 = 5840; reserve = 1/3 = 1946.67; in 22.2 L => 87.7 bar
      expect(p.reserveThresholdBar, closeTo(87.69, 0.1));
      // reserve exit = (5840-3000)/22.2 = 127.9 bar
      expect(p.endReserveBar, closeTo(127.93, 0.1));
      expect(p.ok, isTrue);
    });

    test('fixed reserve with stage = X bar in reserve cylinders', () {
      final p = computeGasPlan(
        rmv: 15,
        avgDepthM: 40,
        timeMin: 40,
        cylinders: const [
          PlanCylinder(11.1),
          PlanCylinder(11.1),
          PlanCylinder(7, keepsReserve: false),
        ],
        startBar: 200,
        rule: ReserveRule.bar50,
      )!;
      expect(p.reserveThresholdBar, closeTo(50, 0.01));
    });

    test('no cylinder marked reserve => all treated as reserve', () {
      final p = computeGasPlan(
        rmv: 20,
        avgDepthM: 30,
        timeMin: 40,
        cylinders: const [
          PlanCylinder(12, keepsReserve: false),
          PlanCylinder(12, keepsReserve: false),
        ],
        startBar: 200,
        rule: ReserveRule.bar35,
      )!;
      expect(p.hasStages, isFalse);
      expect(p.endReserveBar, closeTo(66.67, 0.1)); // same as 1x24
    });

    test('end pressure clamped to start pressure', () {
      final p = computeGasPlan(
        rmv: 1,
        avgDepthM: 10, // 2 ata
        timeMin: 1,
        cylinders: const [PlanCylinder(24)],
        startBar: 200,
        rule: ReserveRule.bar35,
      )!;
      expect(p.endReserveBar, lessThanOrEqualTo(200));
    });

    test('returns null when inputs incomplete or non-positive', () {
      expect(
          computeGasPlan(
              rmv: null,
              avgDepthM: 30,
              timeMin: 40,
              cylinders: const [PlanCylinder(24)],
              startBar: 200,
              rule: ReserveRule.bar35),
          isNull);
      expect(
          computeGasPlan(
              rmv: 20,
              avgDepthM: 30,
              timeMin: 40,
              cylinders: const [],
              startBar: 200,
              rule: ReserveRule.bar35),
          isNull);
      expect(
          computeGasPlan(
              rmv: 20,
              avgDepthM: 30,
              timeMin: 40,
              cylinders: const [PlanCylinder(0)],
              startBar: 200,
              rule: ReserveRule.bar35),
          isNull);
    });
  });
}
