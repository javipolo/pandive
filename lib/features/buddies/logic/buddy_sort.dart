/// Ordena compañeros por nº de buceos (desc) y, a igualdad, por nombre.
/// No hace nada si [byDives] es false (la lista ya viene alfabética).
library;

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/text/collate.dart';

void sortBuddies(List<Buddy> list, bool byDives) {
  if (!byDives) return;
  list.sort((a, b) => a.diveCount == b.diveCount
      ? compareFold(a.name, b.name)
      : b.diveCount.compareTo(a.diveCount));
}
