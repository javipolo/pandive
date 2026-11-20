import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/buddies/logic/buddy_sort.dart';

void main() {
  List<Buddy> sample() => [
        const Buddy(id: 1, name: 'Ana', diveCount: 2),
        const Buddy(id: 2, name: 'Zoe', diveCount: 10),
        const Buddy(id: 3, name: 'bru', diveCount: 2),
      ];

  test('sin byDives no reordena', () {
    final l = sample();
    sortBuddies(l, false);
    expect(l.map((b) => b.id), [1, 2, 3]);
  });

  test('byDives: desc por buceos, luego nombre (fold)', () {
    final l = sample();
    sortBuddies(l, true);
    // Zoe(10), luego empate 2 -> Ana, bru (orden alfabético insensible)
    expect(l.map((b) => b.name), ['Zoe', 'Ana', 'bru']);
  });
}
