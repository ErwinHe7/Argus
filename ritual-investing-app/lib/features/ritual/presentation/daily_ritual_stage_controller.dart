import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/cache/read_cache.dart';
import '../application/daily_ritual_controller.dart';
import '../application/leonidas_voice.dart';
import '../data/daily_ritual_repository.dart';
import '../data/leonidas_voice_preference_store.dart';
import '../domain/daily_ritual.dart';

enum DailyRitualStagePhase {
  resting,
  ready,
  holding,
  acceptedWaiting,
  revealed,
  finishPending,
  closing,
  completed,
  revealFailure,
  finishFailure,
  mediaUnavailable,
}

enum HoldCancellation {
  pointerUp,
  pointerCancel,
  pointerExit,
  tabHidden,
  routeHidden,
  appInactive,
  dateChanged,
  identityChanged,
  semanticCancel,
  navigation,
  disposed,
}

abstract interface class DailyRitualStageAuthority {
  DailyRitual? get current;
  bool get mutationAuthorityEnabled;
  Future<void> revalidate();
  Future<RitualTransitionResult?> reveal();
  Future<RitualTransitionResult?> complete();
  void invalidateForResume();
}

class ControllerDailyRitualStageAuthority implements DailyRitualStageAuthority {
  const ControllerDailyRitualStageAuthority(this.controller);

  final DailyRitualController controller;

  @override
  DailyRitual? get current => controller.state.value;

  @override
  bool get mutationAuthorityEnabled => controller.mutationAuthorityEnabled;

  @override
  Future<void> revalidate() => controller.revalidate();

  @override
  Future<RitualTransitionResult?> reveal() =>
      controller.reveal(waitForHistory: false);

  @override
  Future<RitualTransitionResult?> complete() => controller.complete();

  @override
  void invalidateForResume() => controller.invalidateForResume();
}

abstract interface class DailyRitualStageScheduled {
  void cancel();
}

typedef DailyRitualStageSchedule = DailyRitualStageScheduled Function(
  Duration delay,
  VoidCallback callback,
);
typedef DailyRitualMonotonicNow = Duration Function();
typedef DailyRitualMediaPreparer = Future<bool> Function(DailyRitual ritual);

abstract interface class DailyRitualStageHaptics {
  Future<void> touchDown();
  Future<void> accepted();
}

class PlatformDailyRitualStageHaptics implements DailyRitualStageHaptics {
  const PlatformDailyRitualStageHaptics();

  @override
  Future<void> touchDown() => HapticFeedback.selectionClick();

  @override
  Future<void> accepted() => HapticFeedback.mediumImpact();
}

final Stopwatch _stageProcessClock = Stopwatch()..start();

/// Owns transient Daily Ritual choreography without extending server state.
///
/// Every delayed callback is fenced by [_runToken]. The authoritative
/// controller is still allowed to settle requests after presentation has been
/// invalidated; only obsolete local choreography is ignored.
class DailyRitualStageController extends ChangeNotifier {
  DailyRitualStageController({
    required this.authority,
    required this.scope,
    required this.preferenceStore,
    required this.voice,
    required this.prepareExactMedia,
    DailyRitualStageHaptics? haptics,
    DailyRitualMonotonicNow? monotonicNow,
    DailyRitualStageSchedule? schedule,
    this.holdDuration = const Duration(seconds: 5),
    this.captionsOnlyBeat = const Duration(milliseconds: 1200),
  }) : haptics = haptics ?? const PlatformDailyRitualStageHaptics(),
       _monotonicNow = monotonicNow ?? (() => _stageProcessClock.elapsed),
       _schedule = schedule ?? _scheduleTimer {
    _observedAuthority = authority.current;
    _phase = _phaseForAuthority(_observedAuthority);
  }

  static const _tickInterval = Duration(milliseconds: 50);

  final DailyRitualStageAuthority authority;
  final CacheScope scope;
  final LeonidasVoicePreferencePersistence preferenceStore;
  final LeonidasVoice voice;
  final DailyRitualMediaPreparer prepareExactMedia;
  final DailyRitualStageHaptics haptics;
  final DailyRitualMonotonicNow _monotonicNow;
  final DailyRitualStageSchedule _schedule;
  final Duration holdDuration;
  final Duration captionsOnlyBeat;

  late DailyRitualStagePhase _phase;
  DailyRitual? _observedAuthority;
  HoldCancellation? _cancellation;
  LeonidasVoicePreference _voicePreference = LeonidasVoicePreference.pending;
  DailyRitualStageScheduled? _scheduled;
  Duration? _attemptStartedAt;
  RitualAssignmentLineage? _attemptLineage;
  int? _pointerOwner;
  bool _semanticOwner = false;
  bool _accepted = false;
  bool _preflightReady = false;
  bool _revealDispatched = false;
  bool _closingCaptionVisible = false;
  bool _closingUsesVoice = false;
  bool _speechActive = false;
  bool _speechStopIssued = false;
  bool _skipClosingRequested = false;
  bool _c2Consumed = false;
  bool _visible = true;
  bool _disposed = false;
  int _runToken = 0;
  int _preferenceRevision = 0;

  DailyRitualStagePhase get phase => _phase;
  HoldCancellation? get cancellation => _cancellation;
  LeonidasVoicePreference get voicePreference => _voicePreference;
  bool get isVisible => _visible;
  bool get closingCaptionVisible => _closingCaptionVisible;
  bool get hasActiveHold => _attemptStartedAt != null && !_accepted;
  bool get hasSemanticHold => hasActiveHold && _semanticOwner;
  bool ownsPointer(int pointer) => _pointerOwner == pointer;

  double get holdProgress {
    final startedAt = _attemptStartedAt;
    if (startedAt == null) return _accepted ? 1 : 0;
    final elapsed = _monotonicNow() - startedAt;
    if (elapsed <= Duration.zero) return 0;
    return (elapsed.inMicroseconds / holdDuration.inMicroseconds).clamp(0, 1);
  }

  int get semanticProgressSeconds {
    final startedAt = _attemptStartedAt;
    if (startedAt == null) return _accepted ? holdDuration.inSeconds : 0;
    final elapsed = _monotonicNow() - startedAt;
    return elapsed.inSeconds.clamp(0, holdDuration.inSeconds);
  }

  bool start() {
    if (_disposed || !_visible || _phase != DailyRitualStagePhase.resting) {
      return false;
    }
    final current = authority.current;
    if (!_isStartable(current)) return false;
    _observedAuthority = current;
    _phase = DailyRitualStagePhase.ready;
    _cancellation = null;
    _emit();
    return true;
  }

  bool beginPointerHold(int pointer) {
    if (_pointerOwner != null || _semanticOwner) return false;
    if (!_beginHold()) return false;
    _pointerOwner = pointer;
    return true;
  }

  bool beginSemanticHold() {
    if (_pointerOwner != null || _semanticOwner) return false;
    if (!_beginHold()) return false;
    _semanticOwner = true;
    return true;
  }

  void pointerUp(int pointer) {
    if (_pointerOwner != pointer) return;
    cancel(HoldCancellation.pointerUp);
  }

  void pointerCancel(int pointer) {
    if (_pointerOwner != pointer) return;
    cancel(HoldCancellation.pointerCancel);
  }

  void pointerExit(int pointer) {
    if (_pointerOwner != pointer) return;
    cancel(HoldCancellation.pointerExit);
  }

  void cancel(HoldCancellation reason) {
    if (_disposed || _attemptStartedAt == null) return;
    final elapsed = _monotonicNow() - _attemptStartedAt!;
    if (elapsed > holdDuration) {
      if (!_accepted) _accept(_runToken);
      return;
    }
    _runToken += 1;
    _scheduled?.cancel();
    _scheduled = null;
    _clearAttempt();
    _phase = DailyRitualStagePhase.ready;
    _cancellation = reason;
    _emit();
  }

  void setVisible(bool visible, {required HoldCancellation reason}) {
    if (_disposed || visible == _visible) return;
    _visible = visible;
    if (!visible) {
      _runToken += 1;
      _scheduled?.cancel();
      _scheduled = null;
      _clearAttempt();
      _cancellation = null;
      _closingCaptionVisible = false;
      _stopSpeechOnce();
      authority.invalidateForResume();
      final current = authority.current;
      if (current?.state == DailyRitualState.completed) {
        _phase = DailyRitualStagePhase.completed;
      } else if (current?.state == DailyRitualState.revealed) {
        _phase = DailyRitualStagePhase.revealed;
      } else {
        _phase = DailyRitualStagePhase.resting;
      }
      _emit();
      return;
    }
    final token = _runToken;
    authority.invalidateForResume();
    unawaited(_revalidateAfterResume(token));
    _emit();
  }

  void synchronizeAuthority() {
    if (_disposed) return;
    final current = authority.current;
    final prior = _observedAuthority;
    _observedAuthority = current;
    if (current == null) {
      _invalidateForAuthorityChange(HoldCancellation.identityChanged);
      _phase = DailyRitualStagePhase.resting;
      _emit();
      return;
    }
    if (prior != null && prior.lineage != current.lineage) {
      final reason = prior.date != current.date
          ? HoldCancellation.dateChanged
          : HoldCancellation.identityChanged;
      _invalidateForAuthorityChange(reason);
      _phase = _phaseForAuthority(current);
      _emit();
      return;
    }
    switch (current.state) {
      case DailyRitualState.completed:
        if (_phase != DailyRitualStagePhase.finishPending &&
            _phase != DailyRitualStagePhase.closing) {
          _phase = DailyRitualStagePhase.completed;
          _closingCaptionVisible = false;
        }
      case DailyRitualState.revealed:
        if (_phase != DailyRitualStagePhase.acceptedWaiting &&
            _phase != DailyRitualStagePhase.finishPending &&
            _phase != DailyRitualStagePhase.closing) {
          _phase = DailyRitualStagePhase.revealed;
        }
      case DailyRitualState.assigned:
        if (_phase != DailyRitualStagePhase.ready &&
            _phase != DailyRitualStagePhase.holding &&
            _phase != DailyRitualStagePhase.acceptedWaiting &&
            _phase != DailyRitualStagePhase.revealFailure) {
          _phase = DailyRitualStagePhase.resting;
        }
      case DailyRitualState.unknown:
        _phase = DailyRitualStagePhase.resting;
    }
    _emit();
  }

  bool finish() {
    if (_disposed ||
        !_visible ||
        _phase != DailyRitualStagePhase.revealed ||
        authority.current?.state != DailyRitualState.revealed ||
        authority.current?.hasExactArtIdentity != true ||
        !authority.mutationAuthorityEnabled) {
      return false;
    }
    final current = authority.current!;
    final token = ++_runToken;
    _skipClosingRequested = false;
    _phase = DailyRitualStagePhase.finishPending;
    _cancellation = null;
    _emit();
    unawaited(_complete(token, current));
    return true;
  }

  void skipClosing() {
    if (_disposed) return;
    if (_phase == DailyRitualStagePhase.finishPending) {
      _skipClosingRequested = true;
      return;
    }
    if (_phase != DailyRitualStagePhase.closing) return;
    _runToken += 1;
    _scheduled?.cancel();
    _scheduled = null;
    _stopSpeechOnce();
    _closingCaptionVisible = false;
    _phase = DailyRitualStagePhase.completed;
    _emit();
  }

  Future<void> restoreVoicePreference() async {
    if (_disposed) return;
    final revision = _preferenceRevision;
    final value = await preferenceStore.read(scope);
    if (_disposed || revision != _preferenceRevision) return;
    _voicePreference = value == LeonidasVoicePreference.pending
        ? LeonidasVoicePreference.disabled
        : value;
    _emit();
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    if (_disposed) return;
    final revision = ++_preferenceRevision;
    _voicePreference = enabled
        ? LeonidasVoicePreference.enabled
        : LeonidasVoicePreference.disabled;
    if (!enabled && _phase == DailyRitualStagePhase.closing) {
      _switchClosingToCaptionsOnly();
    }
    _emit();
    try {
      await preferenceStore.write(scope, enabled: enabled);
    } on Object {
      if (_disposed || revision != _preferenceRevision) return;
      _voicePreference = LeonidasVoicePreference.disabled;
      if (_phase == DailyRitualStagePhase.closing) {
        _switchClosingToCaptionsOnly();
      }
      _emit();
    }
  }

  bool _beginHold() {
    if (_disposed ||
        !_visible ||
        (_phase != DailyRitualStagePhase.ready &&
            _phase != DailyRitualStagePhase.revealFailure)) {
      return false;
    }
    final current = authority.current;
    if (!_isStartable(current)) return false;
    final token = ++_runToken;
    _skipClosingRequested = false;
    _attemptStartedAt = _monotonicNow();
    _attemptLineage = current!.lineage;
    _accepted = false;
    _preflightReady = false;
    _revealDispatched = false;
    _cancellation = null;
    _phase = DailyRitualStagePhase.holding;
    _emit();
    unawaited(_haptic(haptics.touchDown));
    unawaited(_prepare(token, current));
    _scheduleTick(token);
    return true;
  }

  Future<void> _prepare(int token, DailyRitual baseline) async {
    var mediaReady = false;
    try {
      final revalidation = authority.revalidate();
      final preparation = prepareExactMedia(baseline);
      await revalidation;
      mediaReady = await preparation;
    } on Object {
      mediaReady = false;
    }
    if (!_isCurrentRun(token)) return;
    _observedAuthority = authority.current;
    final matches =
        authority.mutationAuthorityEnabled &&
        authority.current?.state == DailyRitualState.assigned &&
        authority.current?.lineage == _attemptLineage;
    if (!matches || !mediaReady) {
      _scheduled?.cancel();
      _scheduled = null;
      _clearAttempt();
      _phase = DailyRitualStagePhase.revealFailure;
      _emit();
      return;
    }
    _preflightReady = true;
    _maybeDispatchReveal(token);
  }

  void _scheduleTick(int token) {
    _scheduled?.cancel();
    final startedAt = _attemptStartedAt;
    if (startedAt == null || !_isCurrentRun(token)) return;
    final remaining = holdDuration - (_monotonicNow() - startedAt);
    final delay = remaining <= _tickInterval ? remaining : _tickInterval;
    _scheduled = _schedule(
      delay.isNegative ? Duration.zero : delay,
      () => _tick(token),
    );
  }

  void _tick(int token) {
    if (!_isCurrentRun(token) || _attemptStartedAt == null) return;
    final elapsed = _monotonicNow() - _attemptStartedAt!;
    if (elapsed < holdDuration) {
      _emit();
      _scheduleTick(token);
      return;
    }
    _accept(token);
  }

  void _accept(int token) {
    if (!_isCurrentRun(token) || _attemptStartedAt == null || _accepted) {
      return;
    }
    _accepted = true;
    _pointerOwner = null;
    _semanticOwner = false;
    _phase = DailyRitualStagePhase.acceptedWaiting;
    _scheduled = null;
    _emit();
    unawaited(_haptic(haptics.accepted));
    _maybeDispatchReveal(token);
  }

  void _maybeDispatchReveal(int token) {
    if (!_isCurrentRun(token) ||
        !_accepted ||
        !_preflightReady ||
        _revealDispatched ||
        !_visible) {
      return;
    }
    final current = authority.current;
    if (current?.state != DailyRitualState.assigned ||
        current?.lineage != _attemptLineage ||
        !authority.mutationAuthorityEnabled) {
      _clearAttempt();
      _phase = DailyRitualStagePhase.revealFailure;
      _emit();
      return;
    }
    _revealDispatched = true;
    unawaited(_reveal(token));
  }

  Future<void> _reveal(int token) async {
    RitualTransitionResult? result;
    try {
      result = await authority.reveal();
    } on Object {
      result = null;
    }
    if (!_isCurrentRun(token)) return;
    _observedAuthority = authority.current;
    final current = authority.current;
    final reached =
        _transitionReached(result, DailyRitualState.revealed) &&
        (current?.state == DailyRitualState.revealed ||
            current?.state == DailyRitualState.completed);
    _clearAttempt();
    if (!reached) {
      _phase = DailyRitualStagePhase.revealFailure;
    } else if (current!.state == DailyRitualState.completed) {
      _phase = DailyRitualStagePhase.completed;
    } else {
      _phase = DailyRitualStagePhase.revealed;
    }
    _emit();
  }

  Future<void> _complete(int token, DailyRitual baseline) async {
    RitualTransitionResult? result;
    try {
      result = await authority.complete();
    } on Object {
      result = null;
    }
    if (!_isCurrentRun(token)) return;
    _observedAuthority = authority.current;
    final current = authority.current;
    final reached =
        _transitionReached(result, DailyRitualState.completed) &&
        current?.state == DailyRitualState.completed &&
        baseline.hasSameLineage(current!);
    if (!reached) {
      _phase = DailyRitualStagePhase.finishFailure;
      _emit();
      return;
    }
    if (!_visible || _c2Consumed || _skipClosingRequested) {
      _skipClosingRequested = false;
      _phase = DailyRitualStagePhase.completed;
      _emit();
      return;
    }
    _c2Consumed = true;
    _skipClosingRequested = false;
    _beginClosing(token);
  }

  void _beginClosing(int token) {
    _phase = DailyRitualStagePhase.closing;
    _closingCaptionVisible = true;
    _closingUsesVoice = _voicePreference == LeonidasVoicePreference.enabled;
    _speechActive = false;
    _speechStopIssued = false;
    _emit();
    Future<void>.microtask(() => _startClosingPlayback(token));
  }

  Future<void> _startClosingPlayback(int token) async {
    if (!_isCurrentRun(token) || _phase != DailyRitualStagePhase.closing) {
      return;
    }
    if (!_closingUsesVoice) {
      _scheduleCaptionsBeat(token);
      return;
    }
    _speechActive = true;
    var spoken = false;
    try {
      spoken = await voice.speak(_closingLine);
    } on Object {
      spoken = false;
    }
    if (!_isCurrentRun(token) || _phase != DailyRitualStagePhase.closing) {
      return;
    }
    _speechActive = false;
    if (spoken) {
      _finishClosing(token);
    } else {
      _scheduleCaptionsBeat(token);
    }
  }

  void _switchClosingToCaptionsOnly() {
    if (!_closingUsesVoice && _scheduled != null) return;
    _closingUsesVoice = false;
    _runToken += 1;
    _scheduled?.cancel();
    _scheduled = null;
    _stopSpeechOnce();
    _scheduleCaptionsBeat(_runToken);
  }

  void _scheduleCaptionsBeat(int token) {
    _scheduled?.cancel();
    _scheduled = _schedule(captionsOnlyBeat, () => _finishClosing(token));
  }

  void _finishClosing(int token) {
    if (!_isCurrentRun(token) || _phase != DailyRitualStagePhase.closing) {
      return;
    }
    _scheduled = null;
    _speechActive = false;
    _closingCaptionVisible = false;
    _phase = DailyRitualStagePhase.completed;
    _emit();
  }

  Future<void> _revalidateAfterResume(int token) async {
    try {
      await authority.revalidate();
    } on Object {
      // The authoritative controller owns the visible retry state.
    }
    if (!_isCurrentRun(token) || !_visible) return;
    synchronizeAuthority();
  }

  void _invalidateForAuthorityChange(HoldCancellation reason) {
    _runToken += 1;
    _scheduled?.cancel();
    _scheduled = null;
    _stopSpeechOnce();
    _cancellation = reason;
    _clearAttempt();
    _c2Consumed = false;
    _closingCaptionVisible = false;
  }

  bool _isStartable(DailyRitual? current) =>
      current != null &&
      current.state == DailyRitualState.assigned &&
      current.hasExactArtIdentity &&
      authority.mutationAuthorityEnabled;

  bool _transitionReached(
    RitualTransitionResult? result,
    DailyRitualState target,
  ) =>
      result?.target == target &&
      (result?.disposition == RitualOperationDisposition.committed ||
          result?.disposition == RitualOperationDisposition.reconciledToTarget);

  String get _closingLine {
    final current = authority.current;
    if (current == null) return 'Today’s ritual is complete.';
    return [
      current.rowan.body,
      current.rowan.riskFooter,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  void _clearAttempt() {
    _attemptStartedAt = null;
    _attemptLineage = null;
    _pointerOwner = null;
    _semanticOwner = false;
    _accepted = false;
    _preflightReady = false;
    _revealDispatched = false;
  }

  bool _isCurrentRun(int token) => !_disposed && token == _runToken;

  Future<void> _haptic(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Haptics are optional and never own lifecycle progress.
    }
  }

  void _stopSpeechOnce() {
    if (!_speechActive || _speechStopIssued) return;
    _speechStopIssued = true;
    _speechActive = false;
    unawaited(_stopVoice());
  }

  Future<void> _stopVoice() async {
    try {
      await voice.stop();
    } on Object {
      // Caption state remains complete when native stop is unavailable.
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _runToken += 1;
    _preferenceRevision += 1;
    _scheduled?.cancel();
    _scheduled = null;
    _stopSpeechOnce();
    _clearAttempt();
    _disposed = true;
    super.dispose();
  }

  static DailyRitualStagePhase _phaseForAuthority(DailyRitual? ritual) =>
      switch (ritual?.state) {
        DailyRitualState.revealed => DailyRitualStagePhase.revealed,
        DailyRitualState.completed => DailyRitualStagePhase.completed,
        DailyRitualState.assigned ||
        DailyRitualState.unknown ||
        null => DailyRitualStagePhase.resting,
      };
}

class _TimerScheduled implements DailyRitualStageScheduled {
  _TimerScheduled(this.timer);

  final Timer timer;

  @override
  void cancel() => timer.cancel();
}

DailyRitualStageScheduled _scheduleTimer(
  Duration delay,
  VoidCallback callback,
) => _TimerScheduled(Timer(delay, callback));
