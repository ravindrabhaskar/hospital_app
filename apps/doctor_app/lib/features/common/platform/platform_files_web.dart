import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Revokes the recording's blob URL.
Future<void> deleteTempFile(String path) async {
  try {
    if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
  } catch (_) {}
}

/// Opens [bytes] in the browser's own viewer in a new tab (a user tap, so
/// pop-up blockers allow it). The web build does not load PDF.js from a CDN.
Future<bool> openBytesInBrowser(List<int> bytes, String mimeType) async {
  try {
    final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);
    final win = web.window.open(url, '_blank');
    return win != null;
  } catch (_) {
    return false;
  }
}
