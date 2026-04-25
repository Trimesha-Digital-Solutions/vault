import 'dart:typed_data';

import 'team_file_open_stub.dart'
    if (dart.library.html) 'team_file_open_web.dart'
    if (dart.library.io) 'team_file_open_io.dart' as impl;

Future<void> openDownloadedDocument(Uint8List bytes, String filename) =>
    impl.openDownloadedDocument(bytes, filename);
