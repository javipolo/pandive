/// BLE scan: looks for nearby dive computers and lists them.
/// Phase 2 milestone B. The download (on tapping a device) comes in milestone C.
library;
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/dive_computer.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/screens/download_screen.dart';
import 'package:pandive/features/dive_computer/widgets/scan_widgets.dart';
import 'package:pandive/l10n/app_localizations.dart';
class ScanScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  const ScanScreen({super.key, required this.db, required this.settings});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}
class _ScanScreenState extends State<ScanScreen> {
  final _svc = DiveComputerService();
  final Map<String, ScannedDevice> _devices = {};
  StreamSubscription<ScannedDevice>? _sub;
  String? _error;
  bool _scanning = false;
  bool _permissionOk = false;
  bool _showAll = false; // show all BLE devices, not just diving ones
  bool _btOff = false;
  @override
  void initState() {
    super.initState();
    _start();
  }
  Future<void> _enableBt() async {
    await _svc.requestEnableBluetooth();
    _start();
  }
  Future<void> _start() async {
    setState(() {
      _error = null;
      _btOff = false;
      _devices.clear();
    });
    final ok = await _svc.requestBlePermissions();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    if (!ok) {
      setState(() => (_permissionOk = false, _error = t.btPermsMissing));
      return;
    }
    if (!await _svc.isBluetoothOn()) {
      if (mounted) setState(() => (_error = t.btDisabled, _btOff = true));
      return;
    }
    setState(() {
      _permissionOk = true;
      _scanning = true;
    });
    _sub = _svc.scan().listen(
      (d) => setState(() => _devices[d.id] = d),
      onError: (e) => setState(() {
        _scanning = false;
        _error = t.scanError('$e');
      }),
    );
  }
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
  List<ScannedDevice> get _sorted {
    final list = _devices.values.where((d) => _showAll || d.likely).toList();
    list.sort((a, b) => a.likely != b.likely
        ? (a.likely ? -1 : 1)
        : b.rssi.compareTo(a.rssi));
    return list;
  }
  Future<void> _onTap(ScannedDevice d) async {
    await _sub?.cancel(); // stop scanning before connecting
    if (mounted) setState(() => _scanning = false);
    if (!mounted) return;
    if (!widget.db.isComputerSaved(d.id)) {
      final save = await showSaveComputerDialog(context, d.name);
      if (save == null || !mounted) return;
      if (save) {
        final m = await _svc.matchModel(d.name);
        if (!mounted) return;
        widget.db.addComputer(d.id, d.name, vendor: m?.$1, product: m?.$2);
      }
    }
    if (!mounted) return;
    final action = await showDiveComputerActionSheet(context);
    if (action == null || !mounted) return;
    final n = action == 'sync' ? await askSyncCount(context) : 0;
    if (n == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DownloadScreen(
            device: d, db: widget.db, settings: widget.settings,
            all: action == 'sync', maxDives: n, syncMode: action == 'sync',
            baseline: action == 'mark')));
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final devices = _sorted;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.scanTitle),
        actions: [
          if (_scanning)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
                icon: const Icon(Icons.refresh), tooltip: t.rescan, onPressed: _start),
        ],
      ),
      body: _error != null
          ? ScanErrorView(
              message: _error!,
              onRetry: _start,
              onEnableBt: _btOff ? _enableBt : null)
          : Column(children: [
              if (_permissionOk) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_scanning ? t.scanningHint : t.scanStopped,
                      style: Theme.of(context).textTheme.bodyMedium)),
                CheckboxListTile(
                    dense: true,
                    value: _showAll,
                    title: Text(t.showAllDevices),
                    onChanged: (v) => setState(() => _showAll = v ?? false)),
              ],
              Expanded(
                child: devices.isEmpty
                    ? Center(child: Text(t.noDevicesYet))
                    : ListView.separated(
                        itemCount: devices.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) => ScannedDeviceTile(
                            device: devices[i], onTap: () => _onTap(devices[i]))),
              ),
            ]),
    );
  }
}
