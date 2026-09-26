import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../l10n/app_localizations.dart';
import '../../state/core_providers.dart';
import 'ai_controller.dart';

/// Text-to-speech for assistant replies (§40 "Voice replies").
abstract class SpeechOutput {
  Future<void> speak(String text, {required String languageCode});
  Future<void> stop();
}

/// `flutter_tts` (Android TextToSpeech, iOS AVSpeechSynthesizer, Web Speech).
class FlutterTtsOutput implements SpeechOutput {
  FlutterTts? _tts;

  static const _locales = {'en': 'en-IN', 'hi': 'hi-IN', 'te': 'te-IN'};

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    if (text.trim().isEmpty) return;
    try {
      final tts = _tts ??= FlutterTts();
      final locale = _locales[languageCode] ?? 'en-IN';
      var ok = true;
      try {
        ok = (await tts.isLanguageAvailable(locale)) == true;
      } catch (_) {}
      await tts.setLanguage(ok ? locale : 'en-IN');
      await tts.setSpeechRate(0.5);
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // No TTS engine / voice: fail silently, the text is on screen.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

final speechOutputProvider = Provider<SpeechOutput>((ref) {
  final out = FlutterTtsOutput();
  ref.onDispose(out.stop);
  return out;
});

/// Chat menu → "Read replies aloud" (persisted).
class ReadAloudNotifier extends Notifier<bool> {
  static const key = 'cc_read_aloud';

  @override
  bool build() {
    try {
      return ref.read(sharedPrefsProvider).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggle() async {
    state = !state;
    try {
      await ref.read(sharedPrefsProvider).setBool(key, state);
    } catch (_) {}
  }
}

final readAloudProvider = NotifierProvider<ReadAloudNotifier, bool>(ReadAloudNotifier.new);

/// What to read aloud after a turn completes: the new assistant messages,
/// exactly as the chat displays them. Safety templates are spoken only as
/// the text shown in their red bubble (never instead of showing them).
List<String> textsToSpeak(ChatState prev, ChatState next, AppLocalizations l) {
  if (!(prev.sending && !next.sending)) return const [];
  final before = {for (final m in prev.messages) m.id};
  final out = <String>[];
  for (final m in next.messages) {
    if (before.contains(m.id) || m.isUser) continue;
    if (m.isSafetyAlert) {
      out.add(m.text.isEmpty ? l.emergencyTemplate : m.text);
    } else if (m.text.trim().isNotEmpty) {
      out.add(m.text);
    }
  }
  // The list shows the fixed template when the turn is an emergency without
  // its own safety bubble; read that same text.
  if (next.isEmergency && !next.messages.any((m) => m.isSafetyAlert) && !prev.isEmergency) {
    out.add(l.emergencyTemplate);
  }
  return out;
}
