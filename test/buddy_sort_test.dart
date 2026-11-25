import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/buddies/logic/buddy_sort.dart';

void main() {
  List<Buddy> sample() => [
        Buddy(id: 1, name: 'Ana', diveCount: 2, lastDive: DateTime(2020, 1, 1)),
        Buddy(id: 2, name: 'Zoe', diveCount: 10, lastDive: DateTime(2024, 6, 1)),
        Buddy(id: 3, name: 'bru', diveCount: 2, lastDive: DateTime(2023, 3, 1)),
        const Buddy(id: 4, name: 'Cal', diveCount: 0), // no dives
      ];

  test('name: alfabético (fold)', () {
    final l = sample();
    sortBuddiesBy(l, BuddySort.name);
    expect(l.map((b) => b.name), ['Ana', 'bru', 'Cal', 'Zoe']);
  });

  test('dives: desc por buceos, luego nombre (fold)', () {
    final l = sample();
    sortBuddiesBy(l, BuddySort.dives);
    // Zoe(10), tie at 2 -> Ana, bru, then Cal(0)
    expect(l.map((b) => b.name), ['Zoe', 'Ana', 'bru', 'Cal']);
  });

  test('recent: más reciente primero, sin buceos al final', () {
    final l = sample();
    sortBuddiesBy(l, BuddySort.recent);
    expect(l.map((b) => b.name), ['Zoe', 'bru', 'Ana', 'Cal']);
  });
}
