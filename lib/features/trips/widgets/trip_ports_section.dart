/// Trip ports: optional departure and arrival (shore trips have none), with
/// a "same port for arrival" checkbox (stored as arrival = departure). Each
/// change is saved straight away.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/ports/widgets/port_picker_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TripPortsSection extends StatefulWidget {
  final DivemateDb db;
  final int tripId;
  const TripPortsSection({super.key, required this.db, required this.tripId});

  @override
  State<TripPortsSection> createState() => _TripPortsSectionState();
}

class _TripPortsSectionState extends State<TripPortsSection> {
  Port? _dep;
  Port? _arr;
  bool _same = false;

  @override
  void initState() {
    super.initState();
    final p = widget.db.tripPorts(widget.tripId);
    _dep = p.departure;
    _arr = p.arrival;
    // Default ticked: most boat trips return to where they left from.
    _same = _arr == null || _arr!.id == _dep?.id;
    if (_same) _arr = null;
  }

  void _save() => widget.db.setTripPorts(
    widget.tripId,
    departureId: _dep?.id,
    arrivalId: _same ? _dep?.id : _arr?.id,
  );

  Future<void> _pick(bool departure) async {
    final cur = departure ? _dep : _arr;
    final p = await pickPort(context, widget.db, selectedId: cur?.id);
    if (p == null) return;
    setState(() => departure ? _dep = p : _arr = p);
    _save();
  }

  void _clear(bool departure) {
    setState(() => departure ? _dep = null : _arr = null);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.ports, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        PortPickerField(
          port: _dep,
          placeholder: t.departurePortNone,
          label: t.departurePort,
          onTap: () => _pick(true),
          onClear: () => _clear(true),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _same,
          title: Text(t.arrivalSameAsDeparture),
          onChanged: (v) {
            setState(() => _same = v ?? true);
            _save();
          },
        ),
        if (!_same)
          PortPickerField(
            port: _arr,
            placeholder: t.arrivalPortNone,
            label: t.arrivalPort,
            onTap: () => _pick(false),
            onClear: () => _clear(false),
          ),
      ],
    );
  }
}
