import 'dart:io';

/// Deletes a temporary file (scribe audio must not linger on the device).
Future<void> deleteTempFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

/// Not used on mobile: PDFs render in-app with pdfx.
Future<bool> openBytesInBrowser(List<int> bytes, String mimeType) async => false;
