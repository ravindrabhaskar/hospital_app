import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceStartResult { started, permissionDenied, unavailable }

/// Thin wrapper around speech_to_text that fails soft: any plugin error or
/// denied permission is reported as a result instead of throwing.
class VoiceInput {
  SpeechToText? _stt;
  bool _denied = false;

  Future<VoiceStartResult> start({
    required String localeId,
    required void Function(String) onPartial,
    required void Function(String) onFinal,
    required void Function() onStopped,
  }) async {
    try {
      final stt = _stt ??= SpeechToText();
      final ok = await stt.initialize(
        onError: (SpeechRecognitionError e) {
          if (e.errorMsg.contains('permission')) _denied = true;
          onStopped();
        },
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) onStopped();
        },
      );
      if (!ok) {
        final hasPerm = await stt.hasPermission;
        return (!hasPerm || _denied) ? VoiceStartResult.permissionDenied : VoiceStartResult.unavailable;
      }
      String chosen = localeId;
      try {
        final locales = await stt.locales();
        final match = locales.where((l) => l.localeId.replaceAll('-', '_') == localeId);
        if (match.isEmpty) {
          final lang = localeId.split('_').first;
          final byLang = locales.where((l) => l.localeId.startsWith(lang));
          chosen = byLang.isNotEmpty ? byLang.first.localeId : (await stt.systemLocale())?.localeId ?? localeId;
        }
      } catch (_) {}
      await stt.listen(
        onResult: (r) {
          if (r.finalResult) {
            onFinal(r.recognizedWords);
          } else {
            onPartial(r.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: chosen,
        ),
      );
      return VoiceStartResult.started;
    } catch (_) {
      return _denied ? VoiceStartResult.permissionDenied : VoiceStartResult.unavailable;
    }
  }

  Future<void> stop() async {
    try {
      await _stt?.stop();
    } catch (_) {}
  }
}
