/// File handling for the load screen: where a new logbook goes and how a
/// picked file is read. On Android/Linux files are copied to the app
/// documents; on web they are kept in SQLite's in-memory file system.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/db/open/sqlite_open.dart';
import 'package:pandive/core/platform.dart';

/// Path for a brand-new logbook (unique name).
Future<String> newDbPath() async {
  final name = 'logbook-${DateTime.now().millisecondsSinceEpoch}.ddb';
  if (isWeb) return '/$name';
  final docs = (await getApplicationDocumentsDirectory()).path;
  return '$docs/$name';
}

/// Lets the user pick a .ddb and makes the app's own copy of it. Returns
/// the copy's path, or null if cancelled.
Future<String?> pickDdbCopy() async {
  final res = await FilePicker.platform.pickFiles(withData: isWeb);
  if (res == null) return null;
  final file = res.files.single;
  if (isWeb) {
    final bytes = file.bytes;
    if (bytes == null) return null;
    const dest = '/logbook.ddb';
    await writeDbFile(dest, bytes);
    return dest;
  }
  final path = file.path;
  if (path == null) return null;
  final docs = await getApplicationDocumentsDirectory();
  final dest = '${docs.path}/logbook.ddb';
  await File(path).copy(dest);
  return dest;
}

/// Lets the user pick a text file (e.g. a .ssrf) and returns its content,
/// or null if cancelled.
Future<String?> pickTextFile() async {
  final res = await FilePicker.platform.pickFiles(withData: isWeb);
  if (res == null) return null;
  final file = res.files.single;
  if (isWeb) {
    final bytes = file.bytes;
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }
  final path = file.path;
  return path == null ? null : File(path).readAsString();
}
