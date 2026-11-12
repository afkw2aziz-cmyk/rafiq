import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _listening = false;

  bool get available => _available;
  bool get isListening => _listening;

  Future<bool> init() async {
    if (_available) return true;
    try {
      _available = await _stt.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _listening = false;
        },
        onError: (_) => _listening = false,
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  Future<bool> listen({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!await init()) return false;
    if (_listening) await stop();
    try {
      _listening = true;
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          onDevice: false,
        ),
        onResult: (SpeechRecognitionResult r) {
          if (r.finalResult) _listening = false;
          onResult(r.recognizedWords, r.finalResult);
        },
      );
      return true;
    } catch (_) {
      _listening = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _listening = false;
  }
}
