/// On-disk storage of document images (`documents/` folder
/// inside the app directory). The DB only stores the file name.
/// Lives in `core/` because both the UI and the Drive backup use it.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> documentsDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/documents');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Saves [bytes] as a JPG with a unique name and returns the relative name.
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
