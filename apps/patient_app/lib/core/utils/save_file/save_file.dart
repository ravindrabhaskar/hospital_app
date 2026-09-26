import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart' as impl;

/// Hands a generated file to the user: a browser download on web, the
/// system share sheet (save to Files/Drive, send, ...) on mobile.
Future<void> saveOrShareFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  String? subject,
}) =>
    impl.saveOrShareFile(bytes: bytes, fileName: fileName, mimeType: mimeType, subject: subject);

/// Web only: opens [bytes] in a new browser tab (e.g. a PDF with the
/// browser's viewer). Returns false on platforms without tabs.
Future<bool> openBytesInNewTab({required List<int> bytes, required String mimeType}) =>
    impl.openBytesInNewTab(bytes: bytes, mimeType: mimeType);
