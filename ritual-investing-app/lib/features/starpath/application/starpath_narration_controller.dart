import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/starpath.dart';

enum StarpathNarrationPhase {
  idle,
  starting,
  speaking,
  completed,
  unavailable,
  failure,
}

abstract interface class StarpathNarrationEngine {
  void bind({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required VoidCallback onError,
  });

  Future<bool> configure();

  Future<bool> speak(String text);

  Future<void> stop();

  void dispose();
}

typedef StarpathNarrationEngineFactory = StarpathNarrationEngine Function();

/// A Starpath-level preference shared by every lesson route.
///
/// Narration starts on by default. Once a learner mutes it, the choice remains
/// in effect while they move between Parts and lessons in this Starpath visit.
class StarpathNarrationPreference extends ChangeNotifier {
  StarpathNarrationPreference() : _muted = false;

  bool _muted;

  bool get muted => _muted;

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
  }

  void toggle() => setMuted(!_muted);
}

StarpathNarrationEngine createStarpathNarrationEngine() =>
    FlutterTtsStarpathNarrationEngine();

class FlutterTtsStarpathNarrationEngine implements StarpathNarrationEngine {
  FlutterTtsStarpathNarrationEngine({FlutterTts? tts})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _disposed = false;

  @override
  void bind({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required VoidCallback onError,
  }) {
    _tts.setStartHandler(onStart);
    _tts.setCompletionHandler(onComplete);
    _tts.setCancelHandler(onCancel);
    _tts.setErrorHandler((_) => onError());
  }

  @override
  Future<bool> configure() async {
    final language = await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(kIsWeb ? 0.94 : 0.5);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    return _accepted(language);
  }

  @override
  Future<bool> speak(String text) async => _accepted(await _tts.speak(text));

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_stopSilently());
  }

  bool _accepted(Object? result) => result != false && result != 0;

  Future<void> _stopSilently() async {
    try {
      await _tts.stop();
    } catch (_) {
      // A missing or shutting-down device voice does not block the lesson.
    }
  }
}

class StarpathNarrationController extends ChangeNotifier {
  StarpathNarrationController(this._engine, {required this.script}) {
    _engine.bind(
      onStart: _onStart,
      onComplete: _onComplete,
      onCancel: _onCancel,
      onError: _onError,
    );
    prepare();
  }

  final StarpathNarrationEngine _engine;
  final String script;

  StarpathNarrationPhase _phase = StarpathNarrationPhase.idle;
  Future<bool>? _preparation;
  int _operation = 0;
  bool _active = false;
  bool _busy = false;
  bool _disposed = false;

  StarpathNarrationPhase get phase => _phase;

  bool get isSpeaking => _phase == StarpathNarrationPhase.speaking;

  void prepare() {
    _preparation ??= _configure();
  }

  Future<void> play() async {
    if (_disposed || _busy || isSpeaking) return;
    final shouldRetryPreparation =
        _phase == StarpathNarrationPhase.unavailable ||
        _phase == StarpathNarrationPhase.failure;
    final operation = ++_operation;
    _busy = true;
    _active = true;
    _setPhase(StarpathNarrationPhase.starting);

    if (shouldRetryPreparation) {
      _preparation = _configure();
    }

    try {
      final ready = await (_preparation ??= _configure());
      if (!_isCurrent(operation)) return;
      if (!ready) {
        _active = false;
        _setPhase(StarpathNarrationPhase.unavailable);
        return;
      }

      final accepted = await _engine.speak(script);
      if (!_isCurrent(operation)) return;
      if (!accepted) {
        _active = false;
        _setPhase(StarpathNarrationPhase.unavailable);
      } else if (_phase == StarpathNarrationPhase.starting) {
        _setPhase(StarpathNarrationPhase.speaking);
      }
    } catch (_) {
      if (_isCurrent(operation)) {
        _active = false;
        _setPhase(StarpathNarrationPhase.failure);
      }
    } finally {
      if (_operation == operation) _busy = false;
    }
  }

  Future<void> stop() async {
    if (_disposed || (!_active && !_busy)) return;
    _operation += 1;
    _active = false;
    _busy = false;
    _setPhase(StarpathNarrationPhase.idle);
    try {
      await _engine.stop();
    } catch (_) {
      // The written lesson remains usable even when the device voice fails.
    }
  }

  Future<bool> _configure() async {
    try {
      return await _engine.configure();
    } catch (_) {
      return false;
    }
  }

  bool _isCurrent(int operation) =>
      !_disposed && _active && operation == _operation;

  void _onStart() {
    if (_active) _setPhase(StarpathNarrationPhase.speaking);
  }

  void _onComplete() {
    if (!_active) return;
    _active = false;
    _busy = false;
    _setPhase(StarpathNarrationPhase.completed);
  }

  void _onCancel() {
    if (!_active) return;
    _active = false;
    _busy = false;
    _setPhase(StarpathNarrationPhase.idle);
  }

  void _onError() {
    if (!_active) return;
    _active = false;
    _busy = false;
    _setPhase(StarpathNarrationPhase.failure);
  }

  void _setPhase(StarpathNarrationPhase value) {
    if (_disposed || _phase == value) return;
    _phase = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operation += 1;
    _active = false;
    _engine.dispose();
    super.dispose();
  }
}

String buildStarpathNarrationScript({
  required StarpathNode node,
  required StarpathFactualSection section,
  required int sectionIndex,
  int? displayConstellationOrdinal,
  String? displayConstellationTitle,
  int? displayLessonOrdinal,
}) => [
  'Constellation ${displayConstellationOrdinal ?? node.nodeOrdinal}, ${displayConstellationTitle ?? node.title}.',
  'Lesson ${displayLessonOrdinal ?? sectionIndex + 1}: ${section.heading}.',
  section.body,
  'Keep in mind: ${section.uncertainty}',
].join('\n\n');
