import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<void> openDownloadedDocument(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final safe = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final path = '${dir.path}/vault_$safe';
  await File(path).writeAsBytes(bytes);
  await OpenFile.open(path);
}
