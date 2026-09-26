import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../models/provider_application.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'application_controller.dart';
import 'document_picker.dart';

/// Uploaded documents, in-flight uploads (with progress) and failed uploads
/// (with retry). Adding and deleting are allowed only while editable.
class ApplicationDocumentsCard extends StatelessWidget {
  const ApplicationDocumentsCard({super.key, required this.controller, required this.picker});

  final ApplicationController controller;
  final DocumentPicker picker;

  Future<void> _add(BuildContext context) async {
    final l = context.l10n;
    final docType = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.onbDocType),
        children: [
          for (final t in applicationDocTypes)
            SimpleDialogOption(
              key: Key('docType.$t'),
              onPressed: () => Navigator.pop(context, t),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(docTypeLabel(l, t))),
            ),
        ],
      ),
    );
    if (docType == null || !context.mounted) return;
    final source = await showSourceSheet(context, allowFiles: true);
    if (source == null || !context.mounted) return;
    PickedDocument? file;
    try {
      file = await picker(source);
    } catch (_) {
      file = null;
    }
    if (file == null) return;
    await controller.uploadDocument(docType, file);
  }

  Future<void> _delete(BuildContext context, ApplicationDocument doc) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.onbDeleteDocConfirm),
        content: Text(doc.fileName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          TextButton(
            key: const Key('confirmDeleteDoc'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await controller.deleteDocument(doc.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final app = controller.application;
        if (app == null) return const SizedBox.shrink();
        final editable = app.isEditable;
        final missing = app.missingRequiredDocs;
        return SectionCard(
          key: const Key('documentsCard'),
          title: l.onbDocuments,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (editable)
                Container(
                  key: const Key('docsRequirement'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: missing.isEmpty ? AppColors.mint50 : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(missing.isEmpty
                      ? l.onbDocsComplete
                      : l.onbDocsMissing(missing.map((t) => docTypeLabel(l, t)).join(', '))),
                ),
              if (app.documents.isEmpty && controller.uploads.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.onbNoDocuments, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              for (final d in app.documents)
                ListTile(
                  key: Key('doc.${d.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(d.mimeType == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
                  title: Text(d.fileName, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${docTypeLabel(l, d.docType)} · ${_size(d.sizeBytes)}'),
                  trailing: editable
                      ? IconButton(
                          key: Key('deleteDoc.${d.id}'),
                          tooltip: l.commonDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: controller.busy ? null : () => _delete(context, d),
                        )
                      : null,
                ),
              for (final u in controller.uploads)
                ListTile(
                  key: Key('upload.${u.file.name}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(u.state == UploadState.failed ? Icons.error_outline : Icons.cloud_upload_outlined,
                      color: u.state == UploadState.failed ? AppColors.danger : null),
                  title: Text(u.file.name, overflow: TextOverflow.ellipsis),
                  subtitle: u.state == UploadState.uploading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.onbUploading((u.progress * 100).round())),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: u.progress),
                          ],
                        )
                      : Text(l.onbUploadFailed(errorMessage(l, u.error ?? Exception())),
                          style: const TextStyle(color: AppColors.dangerDeep)),
                  trailing: u.state == UploadState.failed
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.commonRetry,
                              icon: const Icon(Icons.refresh),
                              onPressed: () => controller.retryUpload(u),
                            ),
                            IconButton(
                              tooltip: l.commonCancel,
                              icon: const Icon(Icons.close),
                              onPressed: () => controller.dismissUpload(u),
                            ),
                          ],
                        )
                      : null,
                ),
              if (editable) ...[
                const SizedBox(height: 8),
                Text(l.onbDocsHint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('addDocument'),
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l.onbAddDocument),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil()} KB';
  }
}

/// Camera / gallery / file chooser bottom sheet.
Future<DocumentSource?> showSourceSheet(BuildContext context, {required bool allowFiles}) {
  final l = context.l10n;
  return showModalBottomSheet<DocumentSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('source.camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l.sourceCamera),
            onTap: () => Navigator.pop(context, DocumentSource.camera),
          ),
          ListTile(
            key: const Key('source.gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l.sourceGallery),
            onTap: () => Navigator.pop(context, DocumentSource.gallery),
          ),
          if (allowFiles)
            ListTile(
              key: const Key('source.files'),
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l.sourceFiles),
              onTap: () => Navigator.pop(context, DocumentSource.files),
            ),
        ],
      ),
    ),
  );
}
