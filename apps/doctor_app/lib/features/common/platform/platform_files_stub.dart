/// Deletes a temporary file (no-op where there is no file system).
Future<void> deleteTempFile(String path) async {}

/// Opens [bytes] in a new browser tab (web only). Returns false elsewhere.
Future<bool> openBytesInBrowser(List<int> bytes, String mimeType) async => false;
