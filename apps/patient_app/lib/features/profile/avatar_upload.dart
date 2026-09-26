import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';

/// Centre-crops [bytes] to a square PNG of at most [maxSize] px.
Future<Uint8List> cropSquarePng(Uint8List bytes, {int maxSize = 512}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final side = math.min(image.width, image.height);
  final out = math.min(side, maxSize);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH((image.width - side) / 2, (image.height - side) / 2, side.toDouble(), side.toDouble()),
    Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final cropped = await recorder.endRecording().toImage(out, out);
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  cropped.dispose();
  return data!.buffer.asUint8List();
}

/// The profile avatar with a camera badge; tapping it lets the user pick a
/// photo, which is cropped to a square and uploaded to `POST /me/photo`.
class EditableAvatar extends ConsumerStatefulWidget {
  const EditableAvatar({super.key, required this.name, required this.url, this.size = 76});
  final String name;
  final String? url;
  final double size;

  @override
  ConsumerState<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends ConsumerState<EditableAvatar> {
  bool _busy = false;
  Uint8List? _preview;

  Future<void> _pick() async {
    final l = context.l10n;
    final source = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (c) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(l.takePhoto),
                    onTap: () => Navigator.pop(c, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(l.chooseFromGallery),
                    onTap: () => Navigator.pop(c, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 90);
      if (file == null) return;
      setState(() => _busy = true);
      final raw = await file.readAsBytes();
      Uint8List bytes;
      String name = 'avatar.png', mime = 'image/png';
      try {
        bytes = await cropSquarePng(raw);
      } catch (_) {
        // Undecodable here (e.g. HEIC on some devices): upload as picked.
        bytes = raw;
        name = file.name;
        mime = mimeFromName(file.name);
      }
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) showSnack(context, l.photoTooLarge, error: true);
        return;
      }
      await ref.read(accountRepositoryProvider).uploadPhoto(bytes, fileName: name, mimeType: mime);
      if (!mounted) return;
      setState(() => _preview = bytes);
      ref.invalidate(patientsProvider);
      showSnack(context, l.photoUpdated);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.size;
    return Semantics(
      button: true,
      label: l.changePhoto,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _busy ? null : _pick,
        child: Stack(
          children: [
            _preview != null
                ? ClipOval(child: Image.memory(_preview!, width: s, height: s, fit: BoxFit.cover))
                : Avatar(name: widget.name, url: widget.url, size: s),
            if (_busy)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surface, width: 2),
                ),
                child: const Icon(Icons.photo_camera, size: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
