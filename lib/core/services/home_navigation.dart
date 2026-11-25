/// Navigation requests to the main screen from screens stacked
/// on top (e.g. after importing: go back to the dives list).
library;

import 'package:flutter/foundation.dart';

/// Requested section (bottom bar index); consumed by HomeScreen.
final ValueNotifier<int?> homeSectionRequest = ValueNotifier<int?>(null);

/// Asks to show the dives list (section 0).
void requestDivesList() => homeSectionRequest.value = 0;
