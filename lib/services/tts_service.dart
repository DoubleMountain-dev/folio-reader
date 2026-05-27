// lib/services/tts_service.dart
// Wraps flutter_tts for read-aloud functionality.
// Works in Flutter Web via Web Speech API and natively on Android.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  final ValueNotifier<bool> isPaused   = ValueNotifier(false);
  final ValueNotifier<double> rate     = ValueNotifier(1.0);
  final ValueNotifier<String?> currentVoice = ValueNotifier(null);

  List<Map<String, String>> _voices = [];
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      await _tts.setSpeechRate(_browserRate(1.0));
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        isSpeaking.value = true;
        isPaused.value = false;
      });
      _tts.setCompletionHandler(() {
        isSpeaking.value = false;
        isPaused.value = false;
      });
      _tts.setCancelHandler(() {
        isSpeaking.value = false;
        isPaused.value = false;
      });
      _tts.setPauseHandler(() {
        isPaused.value = true;
      });
      _tts.setContinueHandler(() {
        isPaused.value = false;
      });
      _tts.setErrorHandler((msg) {
        isSpeaking.value = false;
        isPaused.value = false;
      });

      await _loadVoices();
    } catch (_) {}
  }

  Future<void> _loadVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is List) {
        _voices = raw.map<Map<String, String>>((v) {
          if (v is Map) {
            return {
              'name':   v['name']?.toString() ?? 'Voice',
              'locale': v['locale']?.toString() ?? '',
            };
          }
          return {'name': v.toString(), 'locale': ''};
        }).toList();
      }
    } catch (_) { _voices = []; }
  }

  List<Map<String, String>> get voices => _voices;

  Future<void> setVoice(Map<String, String> voice) async {
    try {
      await _tts.setVoice(voice);
      currentVoice.value = voice['name'];
    } catch (_) {}
  }

  Future<void> setRate(double r) async {
    rate.value = r;
    try { await _tts.setSpeechRate(_browserRate(r)); } catch (_) {}
  }

  // Web Speech rate is 0.1-10, where 1.0 is normal.
  double _browserRate(double r) {
    if (kIsWeb) return r.clamp(0.5, 2.0);
    return r.clamp(0.0, 2.0);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> pause() async {
    try { await _tts.pause(); } catch (_) {}
  }

  Future<void> resume() async {
    try {
      isPaused.value = false;
      isSpeaking.value = true;
    } catch (_) {}
  }

  Future<void> stop() async {
    try { await _tts.stop(); } catch (_) {}
    isSpeaking.value = false;
    isPaused.value = false;
  }
}
