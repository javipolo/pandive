/// Importar la imagen de un documento: elegir origen (cámara / galería / PDF),
/// (si PDF, renderizar la página elegida), recortar con nuestra pantalla y
/// guardar como JPG. Devuelve el nombre de fichero guardado, o null si se
/// cancela.
library;

import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import 'package:pandive/features/documents/logic/document_store.dart';
import 'package:pandive/features/documents/screens/crop_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

enum _Src { camera, gallery, pdf }

Future<String?> importDocumentImage(BuildContext context) async {
  final src = await _pickSource(context);
  if (src == null || !context.mounted) return null;
  final Uint8List? raw;
  switch (src) {
    case _Src.camera:
      raw = await _fromPicker(ImageSource.camera);
    case _Src.gallery:
      raw = await _fromPicker(ImageSource.gallery);
    case _Src.pdf:
      raw = await _fromPdf(context);
  }
  if (raw == null || !context.mounted) return null;
  final data = raw;
  final nav = Navigator.of(context);
  final cropped = await nav.push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropScreen(bytes: data)));
  if (cropped == null) return null;
  return saveDocImage(cropped);
}

Future<_Src?> _pickSource(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showModalBottomSheet<_Src>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(t.docSourceCamera),
            onTap: () => Navigator.pop(context, _Src.camera)),
        ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(t.docSourceGallery),
            onTap: () => Navigator.pop(context, _Src.gallery)),
        ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(t.docSourcePdf),
            onTap: () => Navigator.pop(context, _Src.pdf)),
      ]),
    ),
  );
}

Future<Uint8List?> _fromPicker(ImageSource source) async {
  final x = await ImagePicker().pickImage(source: source, imageQuality: 92);
  if (x == null) return null;
  return x.readAsBytes();
}

Future<Uint8List?> _fromPdf(BuildContext context) async {
  final res = await FilePicker.platform
      .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
  final path = res?.files.single.path;
  if (path == null) return null;
  final doc = await PdfDocument.openFile(path);
  var pageNum = 1;
  if (doc.pagesCount > 1 && context.mounted) {
    pageNum = await _pickPage(context, doc.pagesCount) ?? 0;
    if (pageNum == 0) {
      await doc.close();
      return null;
    }
  }
  final page = await doc.getPage(pageNum);
  final rendered = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png);
  await page.close();
  await doc.close();
  return rendered?.bytes;
}

Future<int?> _pickPage(BuildContext context, int count) {
  final t = AppLocalizations.of(context);
  return showDialog<int>(
    context: context,
    builder: (_) => SimpleDialog(
      title: Text(t.docPickPage),
      children: [
        for (var i = 1; i <= count; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: Text(t.docPageN(i)),
          ),
      ],
    ),
  );
}
