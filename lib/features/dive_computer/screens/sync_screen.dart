/// Sincroniza con el ordenador sin bajar todo: descarga lotes crecientes
/// (1, 10, 25…) y para en cuanto encuentra un buceo que ya está en la DB
/// (match por fecha/hora). Importa los más nuevos y fija el fingerprint.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/dive_computer.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/widgets/download_progress.dart';
import 'package:pandive/features/dive_computer/widgets/scan_widgets.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SyncScreen extends StatefulWidget {
  final ScannedDevice device;
  final DivemateDb db;
  final Settings settings;
  const SyncScreen(
      {super.key, required this.db, required this.settings, required this.device});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _svc = DiveComputerService();
  StreamSubscription<double>? _sub;
  double _progress = 0;
  late Future<_Result> _future;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sub = _svc.progress().listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    _future = _run();
  }

  @override
  void dispose() {
    _sub?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<_Result> _run() async {
    final m = modelForDeviceName(widget.device.name);
    if (m == null) {
      return _Result(error: AppLocalizations.of(context)
          .modelNotRecognized(widget.device.name));
    }
    final computer = '${m.$1} ${m.$2}';
    for (final n in const [1, 10, 25, 50, 100, 0]) {
      final res = await _svc.download(
          vendor: m.$1, product: m.$2, address: widget.device.id,
          fingerprint: '', maxDives: n);
      if (!res.ok) return _Result(error: res.error ?? 'Error');
      final dives = res.dives;
      final idx = dives.indexWhere(
          (d) => d.datetime != null && widget.db.hasDiveAt(d.datetime!));
      if (idx >= 0) {
        var added = 0;
        for (final d in dives.take(idx)) {
          if (widget.db.importDownloaded(d, computer: computer)) added++;
        }
        widget.db.setFingerprintFor(widget.device.id, dives[idx].fingerprint);
        return _Result(added: added);
      }
      if (n == 0 || dives.length < n) {
        var added = 0;
        for (final d in dives) {
          if (widget.db.importDownloaded(d, computer: computer)) added++;
        }
        if (dives.isNotEmpty) {
          widget.db.setFingerprintFor(widget.device.id, dives.first.fingerprint);
        }
        return _Result(added: added);
      }
    }
    return _Result(added: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.sync)),
      body: FutureBuilder<_Result>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return DownloadProgress(progress: _progress);
          }
          final r = snap.data;
          if (snap.hasError || r == null || r.error != null) {
            return ScanErrorView(
                message: snap.hasError ? '${snap.error}' : r!.error!,
                onRetry: () => setState(() => _future = _run()));
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 56),
                const SizedBox(height: 12),
                Text(r.added > 0 ? t.savedNew(r.added) : t.syncUpToDate,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(r.added > 0),
                    child: Text(t.done)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Result {
  final int added;
  final String? error;
  const _Result({this.added = 0, this.error});
}
