/// Pantalla de recorte: muestra la imagen, permite rotar en bloques de 90° y
/// arrastrar las esquinas de un rectángulo (sin relación de aspecto fija).
/// Devuelve los bytes recortados (Uint8List) o null si se cancela.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;

import 'package:pandive/l10n/app_localizations.dart';

/// Rota 90° en horario (en isolate vía compute).
Uint8List rotate90(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  return img.encodeJpg(img.copyRotate(decoded, angle: 90), quality: 92);
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
  int _rot = 0;
  bool _busy = false;

  Future<void> _rotate() async {
    setState(() => _busy = true);
    final out = await compute(rotate90, _bytes);
    if (!mounted) return;
    setState(() {
      _bytes = out;
      _rot++;
      _busy = false;
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
              tooltip: t.cropRotate,
              icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
              onPressed: _busy ? null : _rotate),
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
