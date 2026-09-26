import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// A file chosen for upload, held in memory until it is sent.
class PickedDocument {
  const PickedDocument({required this.name, required this.bytes, required this.mimeType});
  final String name;
  final List<int> bytes;
  final String mimeType;
}

enum DocumentSource { camera, gallery, files }

/// Picks a document or image (null if cancelled). Overridable in tests.
typedef DocumentPicker = Future<PickedDocument?> Function(DocumentSource source, {bool imagesOnly});

/// Guesses the upload content type from the file name.
String mimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Default picker: camera/gallery through image_picker (downscaled), files
/// through file_picker (pdf/jpg/png for application documents).
Future<PickedDocument?> pickDocument(DocumentSource source, {bool imagesOnly = false}) async {
  if (source == DocumentSource.files) {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: imagesOnly ? const ['jpg', 'jpeg', 'png', 'webp'] : const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null) return null;
    final bytes = await file.xFile.readAsBytes();
    return PickedDocument(name: file.name, bytes: bytes, mimeType: mimeTypeForName(file.name));
  }
  final image = await ImagePicker().pickImage(
    source: source == DocumentSource.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 80,
    requestFullMetadata: false,
  );
  if (image == null) return null;
  final bytes = await image.readAsBytes();
  final name = image.name.isEmpty ? 'photo.jpg' : image.name;
  return PickedDocument(name: name, bytes: bytes, mimeType: mimeTypeForName(name));
}
