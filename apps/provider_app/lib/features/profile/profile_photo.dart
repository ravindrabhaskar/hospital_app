import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';
import '../onboarding/application_documents.dart' show showSourceSheet;
import '../onboarding/document_picker.dart';

/// Contract §29: jpg/png/webp ≤ 5 MB.
const maxProfilePhotoBytes = 5 * 1024 * 1024;

/// Circular avatar: the profile photo when set, else the initial.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({super.key, required this.name, this.photoUrl, this.radius = 30});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
      style: TextStyle(color: Colors.white, fontSize: radius * 0.8, fontWeight: FontWeight.w700),
    );
    final url = photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      foregroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      onForegroundImageError: url == null || url.isEmpty ? null : (_, _) {},
      child: initial,
    );
  }
}

/// Camera/gallery → preview → `POST /me/photo`.
Future<void> changeProfilePhoto(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final source = await showSourceSheet(context, allowFiles: false);
  if (source == null || !context.mounted) return;
  PickedDocument? picked;
  try {
    picked = await ref.read(documentPickerProvider)(source, imagesOnly: true);
  } catch (_) {
    picked = null;
  }
  if (picked == null || !context.mounted) return;
  if (picked.bytes.length > maxProfilePhotoBytes) {
    messenger.showSnackBar(SnackBar(content: Text(l.avatarTooLarge)));
    return;
  }
  final file = picked;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.avatarPreviewTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.memory(
              Uint8List.fromList(file.bytes),
              key: const Key('avatarPreview'),
              width: 160,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(width: 160, height: 160, child: Icon(Icons.broken_image)),
            ),
          ),
          const SizedBox(height: 12),
          Text(l.avatarPreviewBody, textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        FilledButton(
          key: const Key('avatarUse'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.avatarUse),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final url = await ref
        .read(providerRepositoryProvider)
        .uploadPhoto(bytes: file.bytes, filename: file.name, mimeType: file.mimeType);
    if (url != null && url.isNotEmpty) await ref.read(authControllerProvider).setPhotoUrl(url);
    messenger.showSnackBar(SnackBar(content: Text(l.avatarUploaded)));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(l, e))));
  }
}
