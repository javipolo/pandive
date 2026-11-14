/// "Dive transfer": elige un ordenador guardado (reconecta por MAC sin
/// reescanear) o pulsa Buscar para escanear y guardar uno nuevo.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/dive_computer.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/screens/download_screen.dart';
import 'package:pandive/features/dive_computer/screens/scan_screen.dart';
import 'package:pandive/features/dive_computer/widgets/scan_widgets.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ComputerPickScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  const ComputerPickScreen(
      {super.key, required this.db, required this.settings});

  @override
  State<ComputerPickScreen> createState() => _ComputerPickScreenState();
}

class _ComputerPickScreenState extends State<ComputerPickScreen> {
  late List<DiveComputerRef> _list = widget.db.listComputers();

  void _reload() => setState(() => _list = widget.db.listComputers());

  Future<void> _search() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ScanScreen(db: widget.db, settings: widget.settings)));
    if (mounted) _reload();
  }

  Future<void> _use(DiveComputerRef ref) async {
    final baseline = await showDiveComputerActionSheet(context);
    if (baseline == null || !mounted) return;
    final d = ScannedDevice(
        name: ref.name, id: ref.address, rssi: 0, likely: true);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DownloadScreen(
          device: d,
          db: widget.db,
          settings: widget.settings,
          baseline: baseline),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.diveTransfer)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(t.searchComputer),
            onTap: _search,
          ),
          const Divider(height: 1),
          if (_list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.noComputers, textAlign: TextAlign.center),
            )
          else
            for (final c in _list)
              ListTile(
                leading: const Icon(Icons.watch),
                title: Text(c.name),
                subtitle: Text(c.address),
                onTap: () => _use(c),
              ),
        ],
      ),
    );
  }
}
