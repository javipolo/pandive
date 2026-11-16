/// DEBUG: fija el punto de sincronización en un buceo (su fingerprint) y borra
/// los posteriores, para poder probar "descargar nuevas inmersiones".
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DebugSyncScreen extends StatefulWidget {
  final DivemateDb db;
  const DebugSyncScreen({super.key, required this.db});

  @override
  State<DebugSyncScreen> createState() => _DebugSyncScreenState();
}

class _DebugSyncScreenState extends State<DebugSyncScreen> {
  late final List<DiveComputerRef> _computers = widget.db.listComputers();
  late String? _device = _computers.isNotEmpty ? _computers.first.address : null;
  late List<Dive> _dives = widget.db.listDives();

  Future<void> _set(Dive d) async {
    final t = AppLocalizations.of(context);
    final fp = widget.db.diveFingerprint(d.id);
    final msg = 'Punto de sync en #${d.number} '
        '(${fp != null ? "fp OK" : "sin fp → descarga completa"}). '
        'Borra los posteriores.';
    if (!await confirmDialog(context, msg, confirmLabel: t.confirm)) return;
    widget.db.setSyncPoint(d.id, _device!);
    if (!mounted) return;
    setState(() => _dives = widget.db.listDives());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Hecho')));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt =
        DateFormat('dd/MM/yyyy', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.debugSyncPoint)),
      body: _device == null
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Guarda primero un ordenador de buceo.')))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  initialValue: _device,
                  decoration: const InputDecoration(
                      labelText: 'Ordenador', border: OutlineInputBorder()),
                  items: [
                    for (final c in _computers)
                      DropdownMenuItem(value: c.address, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _device = v),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _dives.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = _dives[i];
                    return ListTile(
                      leading:
                          CircleAvatar(child: Text(d.number?.toString() ?? '—')),
                      title: Text(d.place ?? '—'),
                      subtitle:
                          Text(d.date != null ? fmt.format(d.date!) : '—'),
                      onTap: () => _set(d),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
