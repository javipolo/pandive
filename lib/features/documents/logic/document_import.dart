/// Importar la imagen de un documento: elegir origen (cámara / galería / PDF),
/// (si PDF, renderizar la página elegida), recortar y guardar como JPG. Devuelve
/// el nombre de fichero guardado, o null si se cancela.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'package:pandive/features/documents/logic/document_store.dart';
import 'package:pandive/l10n/app_localizations.dart';

enum _Src { camera, gallery, pdf }

Future<String?> importDocumentImage(BuildContext context) async {
  final src = await _pickSource(context);
  if (src == null) return null;
  final rawPath = switch (src) {
    _Src.camera => await _fromPicker(ImageSource.camera),
    _Src.gallery => await _fromPicker(ImageSource.gallery),
    _Src.pdf => context.mounted ? await _fromPdf(context) : null,
  };
  if (rawPath == null) return null;
  final cropped = await ImageCropper().cropImage(
    sourcePath: rawPath,
    uiSettings: [AndroidUiSettings(hideBottomControls: false)],
  );
  if (cropped == null) return null;
  final bytes = await File(cropped.path).readAsBytes();
  return saveDocImage(bytes);
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

Future<String?> _fromPicker(ImageSource source) async {
  final x = await ImagePicker().pickImage(source: source, imageQuality: 92);
  return x?.path;
}

Future<String?> _fromPdf(BuildContext context) async {
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
  final img = await page.render(
      width: page.width * 2, height: page.height * 2, format: PdfPageImageFormat.png);
  await page.close();
  await doc.close();
  if (img == null) return null;
  final tmp = await getTemporaryDirectory();
  final f = File('${tmp.path}/doc_${DateTime.now().millisecondsSinceEpoch}.png');
  await f.writeAsBytes(img.bytes, flush: true);
  return f.path;
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
