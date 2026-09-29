import 'package:image_picker/image_picker.dart';

/// A picked image, ready for `POST /me/photo` (jpg/png/webp ≤ 5 MB, §29).
class PickedImage {
  const PickedImage({required this.bytes, required this.filename, required this.contentType});
  final List<int> bytes;
  final String filename;
  final String contentType;
}

typedef PhotoPicker = Future<PickedImage?> Function({required bool camera});

Future<PickedImage?> pickProfilePhoto({required bool camera}) async {
  final x = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
    preferredCameraDevice: CameraDevice.front,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final name = x.name.toLowerCase();
  final type =
      x.mimeType ??
      (name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg');
  return PickedImage(bytes: bytes, filename: x.name.isEmpty ? 'photo.jpg' : x.name, contentType: type);
}
