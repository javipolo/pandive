/// Descarga inmersiones de un dispositivo y las guarda (dedupe + fingerprint).
/// En modo [baseline] solo lee la más reciente para fijar el fingerprint
/// (marcar como ya importado) y no guarda nada.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/dive_computer.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/widgets/baseline_done.dart';
import 'package:pandive/features/dive_computer/widgets/download_progress.dart';
import 'package:pandive/features/dive_computer/widgets/download_result_list.dart';
import 'package:pandive/features/dive_computer/widgets/scan_widgets.dart';

class DownloadScreen extends StatefulWidget {
  final ScannedDevice device;
  final DivemateDb db;
  final Settings settings;
  final bool baseline;
  const DownloadScreen({
    super.key,
    required this.device,
    required this.db,
    required this.settings,
    this.baseline = false,
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
  List<DownloadedDive>? _newCache; // inmersiones que no existen en la DB

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
          error: 'Modelo no reconocido por el nombre "${widget.device.name}".');
    }
    final res = await _svc.download(
      vendor: m.$1,
      product: m.$2,
      address: widget.device.id,
      fingerprint:
          widget.baseline ? '' : (widget.settings.dcFingerprint(widget.device.id) ?? ''),
      maxDives: widget.baseline ? 1 : 0,
    );
    if (widget.baseline && res.ok && res.dives.isNotEmpty) {
      await widget.settings
          .setDcFingerprint(widget.device.id, res.dives.first.fingerprint);
    }
    return res;
  }

  Future<void> _save(List<DownloadedDive> dives) async {
    setState(() => _saving = true);
    final computer = _model != null ? '${_model.$1} ${_model.$2}' : null;
    var added = 0;
    for (final d in dives) {
      if (widget.db.importDownloaded(d, computer: computer)) added++;
    }
    final fp = dives.isNotEmpty ? dives.first.fingerprint : '';
    if (fp.isNotEmpty) {
      await widget.settings.setDcFingerprint(widget.device.id, fp);
    }
    if (!mounted) return;
    final skipped = dives.length - added;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Guardadas $added nuevas'
            '${skipped > 0 ? ', $skipped ya existían' : ''}.')));
    Navigator.of(context).pop(added > 0);
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _model != null ? '${_model.$1} ${_model.$2}' : widget.device.name;
    final prefix = widget.baseline ? 'Marcar importado' : 'Descargar';
    return Scaffold(
      appBar: AppBar(title: Text('$prefix · $name')),
      body: FutureBuilder<DownloadResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return DownloadProgress(progress: _progress);
          }
          final res = snap.data;
          final err = snap.hasError
              ? '${snap.error}'
              : (res == null || !res.ok ? (res?.error ?? 'Error') : null);
          if (err != null) {
            return ScanErrorView(
                message: err,
                onRetry: () => setState(() => _future = _download()));
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
    _newCache ??= [
      for (final d in dives)
        if (d.datetime == null || !widget.db.hasDiveAt(d.datetime!)) d,
    ];
    return DownloadResultList(
      total: dives.length,
      newDives: _newCache!,
      saving: _saving,
      onSave: () => _save(dives),
    );
  }
}
