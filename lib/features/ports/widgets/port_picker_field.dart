/// Field showing a chosen port (or [placeholder]) with a boat icon; tap to
/// pick, ✕ to clear. Used in the dive editor and the trip detail.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/ports/screens/port_picker_screen.dart';

/// Opens the port list; returns the picked port (null if cancelled).
Future<Port?> pickPort(
  BuildContext context,
  DivemateDb db, {
  int? selectedId,
}) => Navigator.of(context).push<Port>(
  MaterialPageRoute(
    builder: (_) => PortPickerScreen(db: db, selectedId: selectedId),
  ),
);

class PortPickerField extends StatelessWidget {
  final Port? port;
  final String placeholder; // shown when there is no port
  final String? label; // shown above the name when there is one
  final VoidCallback onTap;
  final VoidCallback onClear;

  const PortPickerField({
    super.key,
    required this.port,
    required this.placeholder,
    required this.onTap,
    required this.onClear,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = port;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.directions_boat_outlined),
        title: Text(p?.name ?? placeholder),
        subtitle: (p != null && label != null) ? Text(label!) : null,
        trailing: p != null
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
