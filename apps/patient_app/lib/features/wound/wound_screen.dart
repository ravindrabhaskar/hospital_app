import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/permissions.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../records/upload_record_screen.dart' show PickedFile, capturePhoto, maxUploadBytes;

class WoundScreen extends ConsumerStatefulWidget {
  const WoundScreen({super.key});

  @override
  ConsumerState<WoundScreen> createState() => _WoundScreenState();
}

class _WoundScreenState extends ConsumerState<WoundScreen> {
  PickedFile? _photo;
  final _site = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  WoundCase? _last;

  @override
  void initState() {
    super.initState();
    _site.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _site.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({bool gallery = false}) async {
    final l = context.l10n;
    try {
      final p = await capturePhoto(gallery: gallery);
      if (p == null || !mounted) return;
      if (p.bytes.length > maxUploadBytes) {
        showSnack(context, l.fileTooLarge, error: true);
        return;
      }
      setState(() {
        _photo = p;
        _last = null;
      });
    } catch (e) {
      if (mounted) showPickerError(context, e);
    }
  }

  Future<void> _submit() async {
    final p = _photo;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final patient = await ref.read(activePatientProvider.future);
      final w = await ref.read(woundRepositoryProvider).submit(
            patientId: patient.id,
            bodySite: _site.text.trim(),
            note: _note.text.trim(),
            bytes: p.bytes,
            fileName: p.name,
            mimeType: p.mimeType,
          );
      ref.invalidate(woundCasesProvider);
      if (mounted) {
        setState(() {
          _last = w;
          if (w.status != 'retake_required') _photo = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _photo;
    return Scaffold(
      appBar: AppBar(title: Text(l.qxWound)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                const _NoDiagnosisNote(),
                const SizedBox(height: Space.lg),
                Semantics(
                  button: true,
                  label: l.uploadWoundPhoto,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.card),
                    onTap: () => _pick(),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(color: context.borderColor, width: 1.5),
                      ),
                      child: p != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(Radii.card),
                              child: Image.memory(Uint8List.fromList(p.bytes),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported)),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(color: context.mintSurface, shape: BoxShape.circle),
                                  child: Icon(Icons.photo_camera_outlined, color: context.brand, size: 30),
                                ),
                                const SizedBox(height: Space.md),
                                Text(l.uploadWoundPhoto, style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(l.woundPhotoTips,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                              ],
                            ),
                    ),
                  ),
                ),
                if (!kIsWeb)
                  TextButton.icon(
                    onPressed: () => _pick(gallery: true),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l.chooseFromGallery),
                  ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _site,
                  decoration: InputDecoration(labelText: l.bodySite, hintText: l.bodySiteHint),
                ),
                const SizedBox(height: Space.md),
                TextField(controller: _note, decoration: InputDecoration(labelText: l.noteOptional)),
                if (_last != null) ...[
                  const SizedBox(height: Space.lg),
                  WoundResultCard(wound: _last!),
                ],
                SectionHeader(title: l.history),
                AsyncView<List<WoundCase>>(
                  value: ref.watch(woundCasesProvider),
                  compact: true,
                  onRetry: () => ref.invalidate(woundCasesProvider),
                  isEmpty: (l) => l.isEmpty,
                  empty: EmptyStateView(compact: true, icon: Icons.healing, title: l.noWoundHistory),
                  data: (list) => Column(
                    children: [for (final w in list) WoundHistoryTile(wound: w)],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
              child: PrimaryButton(
                label: _last?.status == 'retake_required' ? l.retakeAndSubmit : l.sendForReview,
                loading: _busy,
                onPressed: p != null && _site.text.trim().isNotEmpty ? _submit : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDiagnosisNote extends StatelessWidget {
  const _NoDiagnosisNote();

  @override
  Widget build(BuildContext context) {
    return CcCard(
      color: context.skySurface,
      borderColor: context.skySurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_outlined, color: AppColors.skyFg),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.woundNoDiagnosis)),
        ],
      ),
    );
  }
}

class WoundResultCard extends StatelessWidget {
  const WoundResultCard({super.key, required this.wound});
  final WoundCase wound;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final retake = wound.status == 'retake_required';
    return Semantics(
      liveRegion: true,
      child: CcCard(
        color: retake ? context.peachSurface : context.mintSurface,
        borderColor: retake ? AppColors.peachFg : AppColors.primaryLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(retake ? Icons.replay : Icons.hourglass_top,
                    color: retake ? AppColors.peachFg : context.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(retake ? l.woundRetakeTitle : l.woundPendingTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (retake) ...[
              Text(l.woundRetakeBody),
              for (final i in wound.qualityIssues)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.peachFg),
                    const SizedBox(width: 6),
                    Expanded(child: Text(Labels.woundIssue(l, i))),
                  ]),
                ),
            ] else
              Text(l.woundPendingBody),
          ],
        ),
      ),
    );
  }
}

class WoundHistoryTile extends StatelessWidget {
  const WoundHistoryTile({super.key, required this.wound});
  final WoundCase wound;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = wound;
    final (label, color) = switch (w.status) {
      'retake_required' => (l.woundStatusRetake, AppColors.peachFg),
      'reviewed' => (l.woundStatusReviewed, AppColors.primaryLight),
      _ => (l.woundStatusPending, AppColors.skyFg),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.healing, accent: Accent.rose, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.bodySite, style: Theme.of(context).textTheme.titleSmall),
                      Text(fmtDateTime(context, w.createdAt),
                          style: TextStyle(fontSize: 12, color: context.textMuted)),
                    ],
                  ),
                ),
                StatusPill(label: label, color: color),
              ],
            ),
            if (w.reviewNotes != null) ...[
              const SizedBox(height: Space.sm),
              Text(l.clinicianReviewBy(w.reviewerName ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(w.reviewNotes!),
            ],
          ],
        ),
      ),
    );
  }
}
