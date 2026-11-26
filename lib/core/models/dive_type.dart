/// Configurable dive type: name + cylinder template added automatically
/// when picked (e.g. Sidemount → 2×11.1 L) + tags inherited by the dives of
/// that type (derived on read, like site tags).
library;

import 'cylinder.dart';
import 'tag.dart';

class DiveType {
  final int id;
  final String name;
  final List<Cylinder> tanks; // template (litres + material)
  final List<Tag> tags; // inherited by its dives

  const DiveType({
    required this.id,
    required this.name,
    this.tanks = const [],
    this.tags = const [],
  });
}
