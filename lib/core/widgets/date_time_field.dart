/// Date+time picker as a ListTile; handles its own dialogs.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

class DateTimeField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const DateTimeField({super.key, required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    onChanged(DateTime(d.year, d.month, d.day, t?.hour ?? value.hour,
        t?.minute ?? value.minute));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE d MMM yyyy, HH:mm', 'es');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(fmt.format(value)),
      trailing: const Icon(Icons.edit_calendar),
      onTap: () => _pick(context),
    );
  }
}
