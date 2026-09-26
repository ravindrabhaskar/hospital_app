import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> saveOrShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) async {
  await SharePlus.instance.share(ShareParams(
    subject: subject,
    files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType, name: fileName)],
    fileNameOverrides: [fileName],
  ));
}

Future<bool> openBytesInNewTab({required List<int> bytes, required String mimeType}) async => false;
