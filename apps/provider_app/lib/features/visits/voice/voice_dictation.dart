import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text used for "voice-to-note with review before submission"
/// (spec §7). Dictated text only ever lands in an editable field; nothing is
/// submitted automatically.
abstract class VoiceDictation {
  /// Prepares the recognizer (asks for microphone permission). False if
  /// speech recognition is unavailable or permission was denied.
  Future<bool> initialize();

  /// Starts listening. [onFinal] receives each final recognized phrase;
  /// [onDone] fires when listening stops for any reason.
  Future<void> start({
    required String appLanguage,
    required void Function(String text) onFinal,
    required void Function() onDone,
  });

  Future<void> stop();
}

/// Recognizer locale for the app language (en-IN / hi-IN / te-IN), falling
/// back to any locale of the same language, then the device default (null).
String? pickSpeechLocale(String appLanguage, List<String> available) {
  final preferred = switch (appLanguage) {
    'hi' => 'hi_IN',
    'te' => 'te_IN',
    _ => 'en_IN',
  };
  String norm(String id) => id.replaceAll('-', '_').toLowerCase();
  for (final id in available) {
    if (norm(id) == preferred.toLowerCase()) return id;
  }
  final lang = preferred.split('_').first;
  for (final id in available) {
    if (norm(id).startsWith('${lang}_') || norm(id) == lang) return id;
  }
  return null;
}

class SpeechToTextDictation implements VoiceDictation {
  final SpeechToText _speech = SpeechToText();
  void Function()? _onDone;

  @override
  Future<bool> initialize() async {
    try {
      return await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
            final done = _onDone;
            _onDone = null;
            done?.call();
          }
        },
        onError: (_) {
          final done = _onDone;
          _onDone = null;
          done?.call();
        },
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start({
    required String appLanguage,
    required void Function(String text) onFinal,
    required void Function() onDone,
  }) async {
    String? localeId;
    try {
      final locales = await _speech.locales();
      localeId = pickSpeechLocale(appLanguage, [for (final l in locales) l.localeId]);
    } catch (_) {}
    _onDone = onDone;
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) onFinal(r.recognizedWords.trim());
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: false,
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
