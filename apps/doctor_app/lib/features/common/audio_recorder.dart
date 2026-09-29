import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'platform/platform_files.dart';

/// A finished recording, ready for `POST /clinician/appointments/:id/scribe`.
class RecordedAudio {
  const RecordedAudio({required this.bytes, required this.filename, required this.contentType});
  final List<int> bytes;
  final String filename;
  final String contentType;
}

/// Audio capture for the AI scribe (contract §46: webm/m4a/wav ≤ 25 MB).
/// Abstract so widget tests can use a fake.
abstract class ScribeRecorder {
  Future<bool> hasPermission();
  Future<void> start();

  /// Stops and returns the audio; the temporary file is deleted.
  Future<RecordedAudio?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

/// `record` package implementation: AAC/m4a on mobile, Opus/webm on web.
class RecordScribeRecorder implements ScribeRecorder {
  RecordScribeRecorder() : _rec = AudioRecorder();

  final AudioRecorder _rec;
  String? _path;

  bool get _web => kIsWeb;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _rec.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (_web) {
      _path = 'scribe_$ts.webm';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.opus, numChannels: 1), path: _path!);
    } else {
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/scribe_$ts.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, numChannels: 1), path: _path!);
    }
  }

  @override
  Future<RecordedAudio?> stop() async {
    final out = await _rec.stop();
    if (out == null) return null;
    try {
      final bytes = await XFile(out).readAsBytes();
      return RecordedAudio(
        bytes: bytes,
        filename: _web ? 'consultation.webm' : 'consultation.m4a',
        contentType: _web ? 'audio/webm' : 'audio/mp4',
      );
    } finally {
      await deleteTempFile(out);
      _path = null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _rec.cancel();
    } catch (_) {}
    final p = _path;
    if (p != null) await deleteTempFile(p);
    _path = null;
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _rec.dispose();
  }
}
