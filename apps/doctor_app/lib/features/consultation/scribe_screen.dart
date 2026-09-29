import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'scribe_controller.dart';

/// AI scribe page. Pops with the SOAP text to insert into the notes, or null.
class ScribeScreen extends ConsumerStatefulWidget {
  const ScribeScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  ConsumerState<ScribeScreen> createState() => _ScribeScreenState();
}

class _ScribeScreenState extends ConsumerState<ScribeScreen> {
  late final ScribeController _c;
  final _transcript = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = ScribeController(
      appointmentId: widget.appointmentId,
      repository: ref.read(clinicianRepositoryProvider),
      recorderFactory: ref.read(audioRecorderProvider),
    );
    _transcript.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    _transcript.dispose();
    super.dispose();
  }

  String? _errorText(BuildContext context) {
    final l = context.l10n;
    return switch (_c.error) {
      null => null,
      ScribeError.consentMissing => l.scribeConsentRequired,
      ScribeError.micDenied => l.scribeMicDenied,
      ScribeError.emptyTranscript => l.scribeTranscriptShort,
      ScribeError.tooLarge => l.scribeTooLarge,
      ScribeError.failed => _c.cause == null ? l.errorGeneric : errorMessage(l, _c.cause!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final err = _errorText(context);
        final d = _c.draft;
        return FormPage(
          title: l.scribeTitle,
          children: [
            Material(
              color: _c.consent ? AppColors.mint50 : AppColors.warningBg,
              borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
              child: CheckboxListTile(
                key: const Key('scribeConsent'),
                contentPadding: const EdgeInsets.all(8),
                controlAffinity: ListTileControlAffinity.leading,
                value: _c.consent,
                onChanged: (v) => _c.setConsent(v ?? false),
                title: Text(l.scribeConsent, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l.scribeConsentHint),
              ),
            ),
            gap16,
            SectionCard(
              title: l.scribeRecordTitle,
              icon: Icons.mic_none,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_c.recording)
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Text(l.scribeRecording, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (_c.recording) gap8,
                  _c.recording
                      ? FilledButton.icon(
                          key: const Key('scribeStop'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.dangerDeep),
                          onPressed: _c.canStop ? _c.stopAndTranscribe : null,
                          icon: const Icon(Icons.stop),
                          label: Text(l.scribeStopUpload),
                        )
                      : FilledButton.icon(
                          key: const Key('scribeRecord'),
                          onPressed: _c.canRecord ? _c.startRecording : null,
                          icon: const Icon(Icons.mic),
                          label: Text(l.scribeRecord),
                        ),
                  gap8,
                  Text(l.scribeAudioNote, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            gap12,
            SectionCard(
              title: l.scribeTranscriptTitle,
              icon: Icons.notes,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('scribeTranscript'),
                    controller: _transcript,
                    enabled: _c.consent && !_c.recording,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(hintText: l.scribeTranscriptHint),
                  ),
                  gap8,
                  OutlinedButton(
                    key: const Key('scribeGenerate'),
                    onPressed: _c.canGenerate(_transcript.text)
                        ? () => _c.generateFromTranscript(_transcript.text)
                        : null,
                    child: Text(l.scribeGenerate),
                  ),
                ],
              ),
            ),
            if (_c.busy) ...[gap16, const LoadingView()],
            if (err != null) ...[
              gap12,
              Semantics(
                liveRegion: true,
                child: Text(
                  err,
                  key: const Key('scribeError'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
            if (d != null) ...[
              gap16,
              AiAdvisoryCard(
                title: l.scribeDraftTitle,
                footer: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _c.discardDraft, child: Text(l.commonDiscard)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('scribeInsert'),
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(ScribeController.formatSoap(d, s: l.soapS, o: l.soapO, a: l.soapA, p: l.soapP)),
                        child: Text(l.scribeInsert),
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (label, text) in [
                      (l.soapS, d.subjective),
                      (l.soapO, d.objective),
                      (l.soapA, d.assessment),
                      (l.soapP, d.plan),
                    ])
                      if (text.trim().isNotEmpty) LabeledValue(label: label, value: text),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
