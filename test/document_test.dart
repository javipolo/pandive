import 'package:flutter_test/flutter_test.dart';
import 'package:pandive/core/models/models.dart';

void main() {
  DiveDoc doc({bool expires = true, DateTime? expiry}) => DiveDoc(
        id: 1,
        title: 'Nitrox',
        expires: expires,
        expiryDate: expiry,
        fileName: 'a.jpg',
      );

  final now = DateTime(2026, 11, 19);

  test('no expiry => none', () {
    expect(doc(expires: false).status(now), DocStatus.none);
    expect(doc(expiry: null).status(now), DocStatus.none);
  });

  test('past date => expired', () {
    expect(doc(expiry: DateTime(2026, 11, 18)).status(now), DocStatus.expired);
  });

  test('within 30 days => soon', () {
    expect(doc(expiry: DateTime(2026, 11, 19)).status(now), DocStatus.soon);
    expect(doc(expiry: DateTime(2026, 12, 19)).status(now), DocStatus.soon);
  });

  test('beyond 30 days => valid', () {
    expect(doc(expiry: DateTime(2026, 12, 20)).status(now), DocStatus.valid);
  });
}
