import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Holds captured visit photos until they are uploaded.
///
/// The camera's temporary file is copied into the app's private support
/// directory (sandboxed, excluded from backups because the manifest sets
/// `allowBackup=false`) so the OS can't clear it while the upload is queued.
/// Files are deleted as soon as the upload finishes or is dropped, and the
/// whole directory is wiped on logout.
abstract class PhotoFileStore {
  /// Copies [sourcePath] into private storage and returns the new path.
  Future<String> persist(String sourcePath);

  /// File bytes, or null when the file is gone.
  Future<List<int>?> read(String path);

  Future<void> delete(String path);

  Future<void> clear();
}

class LocalPhotoFileStore implements PhotoFileStore {
  LocalPhotoFileStore({Future<Directory> Function()? baseDir, Uuid? uuid})
      : _baseDir = baseDir ?? getApplicationSupportDirectory,
        _uuid = uuid ?? const Uuid();

  final Future<Directory> Function() _baseDir;
  final Uuid _uuid;

  Future<Directory> _dir() async {
    final dir = Directory('${(await _baseDir()).path}${Platform.pathSeparator}visit_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> persist(String sourcePath) async {
    final dir = await _dir();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot > 0 && sourcePath.length - dot <= 5 ? sourcePath.substring(dot).toLowerCase() : '.jpg';
    final target = '${dir.path}${Platform.pathSeparator}${_uuid.v4()}$ext';
    await File(sourcePath).copy(target);
    try {
      await File(sourcePath).delete();
    } catch (_) {}
    return target;
  }

  @override
  Future<List<int>?> read(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Builds the queued body for a consented visit photo (contract §9 fields).
Map<String, dynamic> photoUploadBody({
  required String filePath,
  required String patientId,
  required DateTime takenAt,
}) {
  final d = takenAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final lower = filePath.toLowerCase();
  final mime = lower.endsWith('.png')
      ? 'image/png'
      : lower.endsWith('.heic')
          ? 'image/heic'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
  return {
    'filePath': filePath,
    'patientId': patientId,
    'recordType': 'other',
    'title': 'Home visit photo',
    'recordDate': '${d.year}-${two(d.month)}-${two(d.day)}',
    'mimeType': mime,
    'consentConfirmed': true,
  };
}

/// Takes a photo and returns its temporary path (null if cancelled).
typedef PhotoCapture = Future<String?> Function();

/// Camera only (no gallery): the photo must be taken during the visit.
/// Downscaled/compressed to stay well under the 15 MB upload limit.
Future<String?> captureWithCamera() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 75,
    requestFullMetadata: false,
  );
  return file?.path;
}
