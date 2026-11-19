/// Almacenamiento en disco de las imágenes de documentos (carpeta `documents/`
/// dentro del directorio de la app). La DB solo guarda el nombre de fichero.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> documentsDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/documents');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Guarda [bytes] como JPG con nombre único y devuelve el nombre relativo.
Future<String> saveDocImage(List<int> bytes) async {
  final dir = await documentsDir();
  final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
  return name;
}

Future<File> docFile(String fileName) async =>
    File('${(await documentsDir()).path}/$fileName');

Future<void> deleteDocFile(String fileName) async {
  final f = await docFile(fileName);
  if (await f.exists()) await f.delete();
}
