/// Descarga inmersiones, deja elegir cuáles guardar y avanza el fingerprint.
/// En modo [baseline] solo lee la más reciente para marcarla como importada.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/dive_computer.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/widgets/baseline_done.dart';
import 'package:pandive/features/dive_computer/widgets/download_items.dart';
import 'package:pandive/features/dive_computer/widgets/download_progress.dart';
import 'package:pandive/features/dive_computer/widgets/download_result_list.dart';
import 'package:pandive/features/dive_computer/widgets/scan_widgets.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DownloadScreen extends StatefulWidget {
  final ScannedDevice device;
  final DivemateDb db;
  final Settings settings;
  final bool baseline;
  final bool all; // ignora el fingerprint: baja todas las inmersiones
  final int maxDives; // 0 = sin límite; >0 = solo las N más recientes (sync)
  final bool syncMode; // título "Sincronizar y descargar"
  const DownloadScreen({
    super.key,
    required this.device,
    required this.db,
    required this.settings,
    this.baseline = false,
    this.all = false,
    this.maxDives = 0,
    this.syncMode = false,
  });
  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _svc = DiveComputerService();
  late Future<DownloadResult> _future;
  late final (String, String)? _model;
  StreamSubscription<double>? _progressSub;
  double _progress = 0;
  bool _saving = false;
  List<DownloadItem>? _items; // nuevos del aparato + pendientes
  List<DownloadedDive> _deviceDives = const []; // lo que devolvió el aparato
  int _existing = 0;
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _model = modelForDeviceName(widget.device.name);
    _progressSub = _svc.progress().listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    _future = _download();
  }
  @override
  void dispose() {
    _progressSub?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
  Future<DownloadResult> _download() async {
    final m = _model;
    if (m == null) {
      return DownloadResult(
          error: AppLocalizations.of(context)
              .modelNotRecognized(widget.device.name));
    }
    final res = await _svc.download(
      vendor: m.$1,
      product: m.$2,
      address: widget.device.id,
      fingerprint: (widget.baseline || widget.all)
          ? ''
          : (widget.db.fingerprintFor(widget.device.id) ?? ''),
      maxDives: widget.baseline ? 1 : widget.maxDives,
    );
    if (widget.baseline && res.ok && res.dives.isNotEmpty) {
      widget.db.setFingerprintFor(widget.device.id, res.dives.first.fingerprint);
    }
    return res;
  }
  Future<void> _save(Set<String> selected) async {
    setState(() => _saving = true);
    final computer = _model != null ? '${_model.$1} ${_model.$2}' : null;
    final added = applyDownloadSelection(
      db: widget.db, deviceId: widget.device.id, items: _items!,
      selected: selected, deviceDives: _deviceDives, computer: computer,
    );
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.savedNew(added))));
    Navigator.of(context).pop(added > 0);
  }
  // Por defecto: nuevos marcados, pendientes desmarcados.
  Set<String> get _defaultSel =>
      {for (final it in _items!) if (!it.pending) it.dive.fingerprint};
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final name = _model != null ? '${_model.$1} ${_model.$2}' : widget.device.name;
    final prefix = widget.syncMode ? t.sync : (widget.baseline ? t.markPrefix : t.downloadPrefix);
    return Scaffold(
      appBar: AppBar(title: Text('$prefix · $name')),
      body: FutureBuilder<DownloadResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return DownloadProgress(
                progress: _progress,
                indeterminate: widget.baseline || widget.maxDives > 0);
          }
          final res = snap.data;
          final err = snap.hasError
              ? '${snap.error}'
              : (res == null || !res.ok ? (res?.error ?? 'Error') : null);
          if (err != null) {
            return ScanErrorView(
                message: err, onRetry: () => setState(() => _future = _download()));
          }
          if (widget.baseline) {
            return BaselineDone(onDone: () => Navigator.of(context).pop());
          }
          return _list(res!.dives);
        },
      ),
    );
  }
  Widget _list(List<DownloadedDive> dives) {
    if (_items == null) {
      _deviceDives = dives;
      final r = buildDownloadItems(widget.db, widget.device.id, dives);
      _items = r.items;
      _existing = r.existing;
    }
    return DownloadResultList(
      items: _items!,
      existing: _existing,
      saving: _saving,
      initialSelected: _defaultSel,
      onSave: _save,
    );
  }
}
