import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../ui/l10n_helpers.dart';
import '../../../ui/widgets.dart';

/// Optional "Add photo" card shown while the checkup is in progress.
class VisitPhotoCard extends StatelessWidget {
  const VisitPhotoCard({super.key, required this.onAddPhoto, this.busy = false});

  final VoidCallback onAddPhoto;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      title: l.photoSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.photoSectionHint, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('action.addPhoto'),
            onPressed: busy ? null : onAddPhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l.photoAdd),
          ),
        ],
      ),
    );
  }
}

/// Explicit patient consent before the camera opens. Resolves to true only
/// when the checkbox was ticked and the provider continued.
Future<bool?> showPhotoConsentDialog(BuildContext context) =>
    showDialog<bool>(context: context, builder: (_) => const PhotoConsentDialog());

class PhotoConsentDialog extends StatefulWidget {
  const PhotoConsentDialog({super.key});

  @override
  State<PhotoConsentDialog> createState() => _PhotoConsentDialogState();
}

class _PhotoConsentDialogState extends State<PhotoConsentDialog> {
  bool _consent = false;
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.photoConsentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.photoConsentBody),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('photoConsentCheckbox'),
              value: _consent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.photoConsent),
              subtitle: _showError
                  ? Text(l.photoConsentRequired, style: const TextStyle(color: AppColors.danger))
                  : null,
              onChanged: (v) => setState(() {
                _consent = v ?? false;
                if (_consent) _showError = false;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        FilledButton.icon(
          key: const Key('photoOpenCamera'),
          onPressed: () {
            if (!_consent) {
              setState(() => _showError = true);
              return;
            }
            Navigator.pop(context, true);
          },
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l.photoOpenCamera),
        ),
      ],
    );
  }
}
