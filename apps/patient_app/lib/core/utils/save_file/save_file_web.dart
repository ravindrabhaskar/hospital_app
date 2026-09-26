import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> saveOrShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<bool> openBytesInNewTab({required List<int> bytes, required String mimeType}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final win = web.window.open(url, '_blank');
  // Keep the object URL alive long enough for the new tab to load it.
  Future<void>.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return win != null;
}
