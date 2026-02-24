import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';

class ChallengeService {
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();
  int? _currentChallenge;

  ChallengeService() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.4);
    _tts.setVolume(1.0);
  }

  /// Generate a random 1-digit challenge and speak it via TTS.
  /// Returns the expected digit.
  Future<int> issueChallenge() async {
    _currentChallenge = _random.nextInt(10);
    final message =
        'Press $_currentChallenge to connect.';
    await _tts.speak(message);
    return _currentChallenge!;
  }

  /// Verify a DTMF digit against the current challenge.
  bool verify(String dtmfDigit) {
    if (_currentChallenge == null) return false;
    final digit = int.tryParse(dtmfDigit);
    return digit == _currentChallenge;
  }

  /// Reset the challenge state.
  void reset() {
    _currentChallenge = null;
  }

  int? get currentChallenge => _currentChallenge;

  Future<void> dispose() async {
    await _tts.stop();
  }
}
