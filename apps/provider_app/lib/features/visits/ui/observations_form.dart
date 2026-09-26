import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/home_visit.dart';
import '../../../ui/l10n_helpers.dart';
import '../voice/voice_dictation.dart';

/// Checklist keys sent in `observations.checklist` (booleans).
const observationKeys = [
  'alert_and_oriented',
  'medications_reviewed',
  'mobility_observed',
  'caregiver_present',
  'home_environment_safe',
  'patient_concerns_noted',
];

String observationLabel(AppLocalizations l, String key) => switch (key) {
      'alert_and_oriented' => l.obsAlertOriented,
      'medications_reviewed' => l.obsMedicationsReviewed,
      'mobility_observed' => l.obsMobilityObserved,
      'caregiver_present' => l.obsCaregiverPresent,
      'home_environment_safe' => l.obsHomeSafe,
      'patient_concerns_noted' => l.obsConcernsNoted,
      _ => key,
    };

class ObservationsForm extends StatefulWidget {
  const ObservationsForm({super.key, required this.onSubmit, this.initial, this.busy = false, this.dictation});

  final Future<bool> Function(Map<String, dynamic> body) onSubmit;
  final VisitObservations? initial;
  final bool busy;

  /// Voice-to-note. Dictated text is appended to the notes field for the
  /// provider to review and edit; saving always needs an explicit tap.
  final VoiceDictation? dictation;

  @override
  State<ObservationsForm> createState() => _ObservationsFormState();
}

class _ObservationsFormState extends State<ObservationsForm> {
  late final Map<String, bool> _checks = {
    for (final k in observationKeys) k: widget.initial?.checklist[k] == true,
  };
  late final TextEditingController _notes = TextEditingController(text: widget.initial?.notes ?? '');

  bool _listening = false;
  bool _dictated = false;
  bool? _voiceReady;

  @override
  void dispose() {
    if (_listening) widget.dictation?.stop();
    _notes.dispose();
    super.dispose();
  }

  /// Appends [text] to the notes, separated by a space, cursor at the end.
  void _append(String text) {
    if (!mounted) return;
    final current = _notes.text;
    final sep = current.isEmpty || current.endsWith(' ') || current.endsWith('\n') ? '' : ' ';
    final next = '$current$sep$text';
    final clipped = next.length > 2000 ? next.substring(0, 2000) : next;
    setState(() {
      _notes.value = TextEditingValue(text: clipped, selection: TextSelection.collapsed(offset: clipped.length));
      _dictated = true;
    });
  }

  Future<void> _toggleVoice() async {
    final dictation = widget.dictation;
    if (dictation == null) return;
    if (_listening) {
      await dictation.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final lang = Localizations.localeOf(context).languageCode;
    _voiceReady ??= await dictation.initialize();
    if (_voiceReady != true) {
      _voiceReady = null; // allow retry after granting permission
      messenger?.showSnackBar(SnackBar(content: Text(l.voiceUnavailable)));
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await dictation.start(
      appLanguage: lang,
      onFinal: _append,
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in observationKeys)
          CheckboxListTile(
            key: Key('obs.$key'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _checks[key],
            title: Text(observationLabel(l, key)),
            onChanged: (v) => setState(() => _checks[key] = v ?? false),
          ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('obsNotes'),
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: l.obsNotes,
            hintText: l.obsNotesHint,
            suffixIcon: widget.dictation == null
                ? null
                : IconButton(
                    key: const Key('obsDictate'),
                    tooltip: _listening ? l.voiceStop : l.voiceDictate,
                    color: _listening ? AppColors.danger : null,
                    icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
                    onPressed: widget.busy ? null : _toggleVoice,
                  ),
          ),
        ),
        if (_listening)
          Semantics(
            liveRegion: true,
            child: Text(l.voiceListening, key: const Key('obsListening'), style: const TextStyle(color: AppColors.danger)),
          )
        else if (_dictated)
          Semantics(
            liveRegion: true,
            child: Text(l.voiceReview,
                key: const Key('obsDictationReview'), style: const TextStyle(color: Color(0xFF9A5A10))),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('obsSave'),
          onPressed: widget.busy
              ? null
              : () => widget.onSubmit({
                    'notes': _notes.text.trim(),
                    'checklist': Map<String, dynamic>.from(_checks),
                  }),
          child: Text(l.obsSave),
        ),
      ],
    );
  }
}
