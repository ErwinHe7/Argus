import 'package:flutter/services.dart';

abstract interface class LeonidasVoice {
  /// Returns true when a platform voice spoke the full line.
  ///
  /// False means the caller must retain the caption and provide its own pacing.
  Future<bool> speak(String text);

  Future<void> stop();
}

class PlatformLeonidasVoice implements LeonidasVoice {
  const PlatformLeonidasVoice();

  static const MethodChannel _channel = MethodChannel(
    'ritual_investing/leonidas_voice',
  );

  @override
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('speak', <String, Object>{
            'text': text,
            'rate': 0.91,
            'pitch': 0.78,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Captions remain the complete fallback when speech is unavailable.
    } on PlatformException {
      // Stopping speech is best-effort and must not block the ritual.
    }
  }
}
