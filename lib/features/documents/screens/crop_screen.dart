/// Pantalla de recorte: muestra la imagen, permite rotar en bloques de 90° y
/// arrastrar las esquinas de un rectángulo (sin relación de aspecto fija).
/// Devuelve los bytes recortados (Uint8List) o null si se cancela.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;

import 'package:pandive/l10n/app_localizations.dart';

/// Rota 90° en horario / antihorario (en isolate vía compute).
Uint8List rotateCw(Uint8List bytes) => _rotate(bytes, 90);
Uint8List rotateCcw(Uint8List bytes) => _rotate(bytes, -90);

Uint8List _rotate(Uint8List bytes, int angle) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  return img.encodeJpg(img.copyRotate(decoded, angle: angle), quality: 92);
}

/// Reduce a un máximo de 2200 px por lado (una vez al entrar), para que rotar
/// después sea rápido. Suficiente resolución para un documento/carnet.
Uint8List downscaleForCrop(Uint8List bytes) {
  final d = img.decodeImage(bytes);
  if (d == null) return bytes;
  const maxSide = 2200;
  if (d.width <= maxSide && d.height <= maxSide) return bytes;
  final resized = d.width >= d.height
      ? img.copyResize(d, width: maxSide)
      : img.copyResize(d, height: maxSide);
  return img.encodeJpg(resized, quality: 90);
}

class CropScreen extends StatefulWidget {
  final Uint8List bytes;
  const CropScreen({super.key, required this.bytes});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();
  late Uint8List _bytes = widget.bytes;
  Uint8List? _original; // imagen reducida sin rotar (para reset)
  int _rot = 0;
  bool _busy = true; // empieza ocupado: reduce la imagen al entrar

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final out = await compute(downscaleForCrop, _bytes);
    if (!mounted) return;
    setState(() {
      _bytes = out;
      _original = out;
      _busy = false;
    });
  }

  Future<void> _apply(Uint8List Function(Uint8List) op) async {
    setState(() => _busy = true);
    final out = await compute(op, _bytes);
    if (!mounted) return;
    setState(() {
      _bytes = out;
      _rot++;
      _busy = false;
    });
  }

  void _reset() {
    final o = _original;
    if (o == null) return;
    setState(() {
      _bytes = o;
      _rot++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.cropTitle),
        actions: [
          IconButton(
              tooltip: t.cropRotateLeft,
              icon: const Icon(Icons.rotate_90_degrees_ccw_outlined),
              onPressed: _busy ? null : () => _apply(rotateCcw)),
          IconButton(
              tooltip: t.cropRotate,
              icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
              onPressed: _busy ? null : () => _apply(rotateCw)),
          IconButton(
              tooltip: t.cropReset,
              icon: const Icon(Icons.restart_alt),
              onPressed: _busy ? null : _reset),
          IconButton(
              tooltip: t.confirm,
              icon: const Icon(Icons.check),
              onPressed: _busy ? null : () => _controller.crop()),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Crop(
              key: ValueKey(_rot),
              image: _bytes,
              controller: _controller,
              aspectRatio: null, // relación libre
              baseColor: Colors.black,
              maskColor: Colors.black54,
              onCropped: (result) {
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.of(context).pop(croppedImage);
                  case CropFailure():
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(t.cropFailed)));
                }
              },
            ),
    );
  }
}
