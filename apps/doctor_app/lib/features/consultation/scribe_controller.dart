import 'package:flutter/foundation.dart';

import '../../data/clinician_repository.dart';
import '../../models/care.dart';
import '../common/audio_recorder.dart';

enum ScribeError { consentMissing, micDenied, emptyTranscript, tooLarge, failed }

/// AI scribe (contract §46). Nothing can be recorded, uploaded or sent until
/// the doctor confirms the patient agreed (`consentConfirmed: true`, audited).
/// The SOAP draft is advisory and is only inserted into the notes on an
/// explicit tap; it is never saved automatically.
class ScribeController extends ChangeNotifier {
  ScribeController({required this.appointmentId, required this.repository, required this.recorderFactory});

  final String appointmentId;
  final ClinicianRepository repository;
  final ScribeRecorder Function() recorderFactory;

  static const maxAudioBytes = 25 * 1024 * 1024;
  static const minTranscriptLength = 20;

  ScribeRecorder? _recorder;
  bool _consent = false;
  bool _recording = false;
  bool _busy = false;
  ScribeDraft? _draft;
  ScribeError? _error;
  Object? _cause;

  bool get consent => _consent;
  bool get recording => _recording;
  bool get busy => _busy;
  ScribeDraft? get draft => _draft;
  ScribeError? get error => _error;
  Object? get cause => _cause;

  bool get canRecord => _consent && !_busy && !_recording;
  bool get canStop => _consent && _recording && !_busy;
  bool canGenerate(String transcript) =>
      _consent && !_busy && !_recording && transcript.trim().length >= minTranscriptLength;

  Future<void> setConsent(bool value) async {
    _consent = value;
    if (!value && _recording) {
      // Withdrawing consent discards the recording in progress.
      await _recorder?.cancel();
      _recording = false;
    }
    _error = null;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (!_consent) return _fail(ScribeError.consentMissing);
    if (!canRecord) return;
    _recorder ??= recorderFactory();
    if (!await _recorder!.hasPermission()) return _fail(ScribeError.micDenied);
    try {
      await _recorder!.start();
      _recording = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _fail(ScribeError.failed, e);
    }
  }

  /// Stops, uploads the audio (multipart `audio`) and loads the draft.
  Future<void> stopAndTranscribe() async {
    if (!_consent) return _fail(ScribeError.consentMissing);
    if (!canStop) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final audio = await _recorder!.stop();
      _recording = false;
      if (audio == null || audio.bytes.isEmpty) {
        _fail(ScribeError.failed);
        return;
      }
      if (audio.bytes.length > maxAudioBytes) {
        _fail(ScribeError.tooLarge);
        return;
      }
      _draft = await repository.scribeFromAudio(
        appointmentId,
        audio.bytes,
        filename: audio.filename,
        contentType: audio.contentType,
      );
    } catch (e) {
      _recording = false;
      _fail(ScribeError.failed, e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Typed / pasted transcript (JSON body).
  Future<void> generateFromTranscript(String transcript) async {
    if (!_consent) return _fail(ScribeError.consentMissing);
    if (transcript.trim().length < minTranscriptLength) return _fail(ScribeError.emptyTranscript);
    if (_busy || _recording) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _draft = await repository.scribeFromTranscript(appointmentId, transcript.trim());
    } catch (e) {
      _fail(ScribeError.failed, e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void discardDraft() {
    _draft = null;
    notifyListeners();
  }

  void _fail(ScribeError e, [Object? cause]) {
    _error = e;
    _cause = cause;
    notifyListeners();
  }

  /// Plain-text SOAP block for the notes field.
  static String formatSoap(
    ScribeDraft d, {
    required String s,
    required String o,
    required String a,
    required String p,
  }) => [
    if (d.subjective.trim().isNotEmpty) '$s: ${d.subjective.trim()}',
    if (d.objective.trim().isNotEmpty) '$o: ${d.objective.trim()}',
    if (d.assessment.trim().isNotEmpty) '$a: ${d.assessment.trim()}',
    if (d.plan.trim().isNotEmpty) '$p: ${d.plan.trim()}',
  ].join('\n');

  @override
  void dispose() {
    final r = _recorder;
    if (r != null) r.dispose();
    super.dispose();
  }
}
