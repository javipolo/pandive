/// Configurable dive type: name + cylinder template added
/// automatically when picked (e.g. Sidemount → 2×11.1 L).
library;

import 'cylinder.dart';

class DiveType {
  final int id;
  final String name;
  final List<Cylinder> tanks; // template (litres + material)

  const DiveType({
    required this.id,
    required this.name,
    this.tanks = const [],
  });
}
