import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> init({double rate = 0.5}) async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(1.05);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
    _ready = true;
  }

  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
  }) async {
    if (text.trim().isEmpty) return;
    try {
      await init(rate: rate);
      await _tts.setSpeechRate(rate);
      final ok = await _tts.setLanguage(locale);
      if (ok != 1 && locale.startsWith('ar')) {
        // Fall back to the device default voice; better than silence.
        await _tts.setLanguage('en-US');
      }
      _speaking = true;
      await _tts.speak(text);
    } catch (_) {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }
}
