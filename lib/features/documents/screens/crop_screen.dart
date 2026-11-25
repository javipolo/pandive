/// Crop screen: shows the image, allows rotating in 90° steps and
/// dragging the corners of a rectangle (no fixed aspect ratio).
/// Returns the cropped bytes (Uint8List) or null if cancelled.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;

import 'package:pandive/l10n/app_localizations.dart';

/// Rotates 90° clockwise / counter-clockwise (in an isolate via compute).
Uint8List rotateCw(Uint8List bytes) => _rotate(bytes, 90);
Uint8List rotateCcw(Uint8List bytes) => _rotate(bytes, -90);

Uint8List _rotate(Uint8List bytes, int angle) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  return img.encodeJpg(img.copyRotate(decoded, angle: angle), quality: 92);
}

/// Downscales to at most 2200 px per side (once on entry), so rotating
/// later is fast. Enough resolution for a document/ID card.
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
  Uint8List? _original; // downscaled unrotated image (for reset)
  int _rot = 0;
  bool _busy = true; // starts busy: downscales the image on entry

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
              aspectRatio: null, // free ratio
              // Initial rectangle = whole image (maximised); it shrinks.
              initialRectBuilder:
                  InitialRectBuilder.withBuilder((viewport, image) => image),
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
