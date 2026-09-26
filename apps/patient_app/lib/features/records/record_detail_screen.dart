import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pdf_viewer.dart';
import '../../core/widgets/state_views.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  bool _summarizing = false;
  bool _opening = false;

  Future<void> _summarize() async {
    final l = context.l10n;
    setState(() => _summarizing = true);
    try {
      await ref.read(recordsRepositoryProvider).summarize(widget.id);
      ref.invalidate(recordProvider(widget.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConsentRequired) {
        final grant = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.aiConsentTitle),
            content: Text(l.aiConsentBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.notNow)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.allowAiAssistance)),
            ],
          ),
        );
        if (grant == true) {
          try {
            await ref.read(consentRepositoryProvider).grantPurpose('ai_assistance');
            if (mounted) {
              setState(() => _summarizing = false);
              await _summarize();
              return;
            }
          } catch (e2) {
            if (mounted) showSnack(context, errorMessage(context, e2), error: true);
          }
        }
      } else {
        showSnack(context, errorMessage(context, e), error: true);
      }
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _open(MedicalRecord r) async {
    final l = context.l10n;
    if (r.isPdf) {
      // In-app viewer (pdfx) on Android/iOS; browser tab on web.
      await openPdf(
        context,
        title: r.title,
        fileName: r.fileName.isEmpty ? '${r.title}.pdf' : r.fileName,
        load: () => ref.read(recordsRepositoryProvider).file(r.id),
      );
      return;
    }
    setState(() => _opening = true);
    try {
      final bytes = Uint8List.fromList(await ref.read(recordsRepositoryProvider).file(r.id));
      if (!mounted) return;
      if (r.isImage) {
        await showDialog<void>(
          context: context,
          builder: (c) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
                TextButton(onPressed: () => Navigator.pop(c), child: Text(l.close)),
              ],
            ),
          ),
        );
      } else if (kIsWeb) {
        // Other non-image files: hand them to the browser.
        final ok = await launchUrl(Uri.dataFromBytes(bytes, mimeType: r.mimeType));
        if (!ok && mounted) showSnack(context, l.previewUnavailable);
      } else {
        showSnack(context, l.previewUnavailableMobile(fmtBytes(bytes.length)));
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.record)),
      body: AsyncView<MedicalRecord>(
        value: ref.watch(recordProvider(widget.id)),
        onRetry: () => ref.invalidate(recordProvider(widget.id)),
        data: (r) => ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Row(
              children: [
                IconTile(icon: Labels.recordIcon(r.type), accent: Labels.recordAccent(r.type), size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      ProvenanceBadge(source: r.source),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            CcCard(
              child: Column(
                children: [
                  LabeledValue(label: l.recordType, value: Labels.recordType(l, r.type)),
                  LabeledValue(label: l.recordDate, value: fmtYmd(context, r.recordDate)),
                  if (r.uploadedByName != null) LabeledValue(label: l.addedBy, value: r.uploadedByName!),
                  if (r.fileName.isNotEmpty) LabeledValue(label: l.file, value: r.fileName),
                  if (r.sizeBytes > 0) LabeledValue(label: l.size, value: fmtBytes(r.sizeBytes)),
                  if (r.createdAt != null) LabeledValue(label: l.uploadedOn, value: fmtDateTime(context, r.createdAt!)),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            if (r.hasFile)
              OutlinedButton.icon(
                onPressed: _opening ? null : () => _open(r),
                icon: _opening
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(r.isPdf ? Icons.picture_as_pdf_outlined : Icons.open_in_new),
                label: Text(r.isPdf ? l.viewPdf : l.openOriginal),
              ),
            SectionHeader(title: l.aiSummary),
            if (r.aiSummary != null)
              AiSummaryPanel(summary: r.aiSummary!)
            else
              PrimaryButton(
                label: l.summarizeWithAi,
                icon: Icons.auto_awesome,
                loading: _summarizing,
                onPressed: _summarize,
              ),
            const SizedBox(height: Space.md),
            Text(l.originalImmutableNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
      ),
    );
  }
}

class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge({super.key, required this.source});
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StatusPill(
      label: l.sourceLabel(Labels.provenance(l, source)),
      color: Labels.provenanceColor(source),
      icon: source == 'clinician_verified' ? Icons.verified : Icons.info_outline,
    );
  }
}

class AiSummaryPanel extends StatelessWidget {
  const AiSummaryPanel({super.key, required this.summary});
  final AiSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: context.lavenderSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.lavenderFg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiGeneratedLabel(),
          const SizedBox(height: Space.sm),
          Text(summary.text, style: const TextStyle(height: 1.45)),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.lavenderFg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(summary.disclaimer.isEmpty ? l.aiDisclaimerDefault : summary.disclaimer,
                    style: TextStyle(fontSize: 12, color: context.textMuted)),
              ),
            ],
          ),
          if (summary.generatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.generatedOn(fmtDateTime(context, summary.generatedAt!)),
                  style: TextStyle(fontSize: 11, color: context.textMuted)),
            ),
        ],
      ),
    );
  }
}
