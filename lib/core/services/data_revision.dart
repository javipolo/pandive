/// Global "data has changed" signal to refresh the tabs without
/// closing/reopening the database (soft reload). Used by the tools
/// that write to the already open DB (enrich, tags, trash…).
library;

import 'package:flutter/foundation.dart';

final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

void bumpDataRevision() => dataRevision.value++;
