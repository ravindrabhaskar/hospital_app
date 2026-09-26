import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../onboarding/profile_setup_screen.dart' show DateField;

const maxUploadBytes = 15 * 1024 * 1024;
const allowedUploadExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'];

class PickedFile {
  PickedFile(this.name, this.bytes, this.mimeType);
  final String name;
  final List<int> bytes;
  final String mimeType;
}

/// Picks a document (PDF/image) with file_picker. Returns null if cancelled.
Future<PickedFile?> pickDocument({bool imagesOnly = false}) async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: imagesOnly ? const ['jpg', 'jpeg', 'png', 'webp', 'heic'] : allowedUploadExtensions,
  );
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  return PickedFile(f.name, bytes, mimeFromName(f.name));
}

/// Takes a photo with the camera (falls back to gallery where no camera).
Future<PickedFile?> capturePhoto({bool gallery = false}) async {
  final x = await ImagePicker().pickImage(
    source: gallery || kIsWeb ? ImageSource.gallery : ImageSource.camera,
    maxWidth: 2400,
    imageQuality: 88,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final name = x.name.isEmpty ? 'photo.jpg' : x.name;
  final mime = x.mimeType ?? mimeFromName(name);
  return PickedFile(name, bytes, mime == 'application/octet-stream' ? 'image/jpeg' : mime);
}

class UploadRecordScreen extends ConsumerStatefulWidget {
  const UploadRecordScreen({super.key, this.initialType});
  final String? initialType;

  @override
  ConsumerState<UploadRecordScreen> createState() => _UploadRecordScreenState();
}

class _UploadRecordScreenState extends ConsumerState<UploadRecordScreen> {
  late String _type =
      RecordType.uploadable.contains(widget.initialType) ? widget.initialType! : RecordType.labReport;
  final _title = TextEditingController();
  DateTime _date = DateTime.now();
  PickedFile? _file;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<PickedFile?> Function() picker) async {
    final l = context.l10n;
    try {
      final f = await picker();
      if (f == null || !mounted) return;
      if (f.bytes.length > maxUploadBytes) {
        showSnack(context, l.fileTooLarge, error: true);
        return;
      }
      setState(() {
        _file = f;
        if (_title.text.trim().isEmpty) {
          _title.text = f.name.contains('.') ? f.name.substring(0, f.name.lastIndexOf('.')) : f.name;
        }
      });
    } catch (_) {
      if (mounted) showSnack(context, l.pickerFailed, error: true);
    }
  }

  Future<void> _upload() async {
    final l = context.l10n;
    final f = _file;
    if (f == null) return;
    setState(() => _uploading = true);
    try {
      final patient = await ref.read(activePatientProvider.future);
      final rec = await ref.read(recordsRepositoryProvider).upload(
            patientId: patient.id,
            type: _type,
            title: _title.text.trim(),
            recordDate: ymd(_date),
            bytes: f.bytes,
            fileName: f.name,
            mimeType: f.mimeType,
          );
      for (final t in [null, ...RecordType.all]) {
        ref.invalidate(recordsProvider(t));
      }
      ref.invalidate(timelineProvider);
      if (!mounted) return;
      showSnack(context, l.uploaded);
      if (widget.initialType == RecordType.prescription) {
        context.pop(rec.id);
      } else {
        context.pushReplacement('/records/${rec.id}');
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = _file;
    return Scaffold(
      appBar: AppBar(title: Text(l.uploadNewReport)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon: Icons.upload_file,
                  label: l.chooseFile,
                  onTap: () => _pick(pickDocument),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _PickButton(
                  icon: Icons.photo_camera_outlined,
                  label: kIsWeb ? l.choosePhoto : l.takePhoto,
                  onTap: () => _pick(capturePhoto),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (f != null)
            CcCard(
              color: context.mintSurface,
              child: Row(
                children: [
                  Icon(f.mimeType.startsWith('image/') ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${f.name} · ${fmtBytes(f.bytes.length)}')),
                  IconButton(
                      tooltip: l.remove,
                      onPressed: () => setState(() => _file = null),
                      icon: const Icon(Icons.close)),
                ],
              ),
            )
          else
            Text(l.allowedFiles, style: TextStyle(color: context.textMuted, fontSize: 12.5)),
          const SizedBox(height: Space.xl),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(labelText: l.recordType),
            items: [
              for (final t in RecordType.uploadable)
                DropdownMenuItem(value: t, child: Text(Labels.recordType(l, t))),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: Space.lg),
          TextField(controller: _title, decoration: InputDecoration(labelText: l.title)),
          const SizedBox(height: Space.lg),
          DateField(
            label: l.recordDate,
            value: _date,
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _date, firstDate: DateTime(1950), lastDate: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: Space.md),
          Text(l.uploadPrivacyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
          const SizedBox(height: Space.xxl),
          PrimaryButton(
            label: l.upload,
            loading: _uploading,
            onPressed: f != null && _title.text.trim().isNotEmpty ? _upload : null,
          ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CcCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: ExcludeSemantics(
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
