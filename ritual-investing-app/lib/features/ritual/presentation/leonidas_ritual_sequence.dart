import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/cache/read_cache.dart';
import '../application/daily_ritual_controller.dart';
import '../application/leonidas_voice.dart';
import '../data/daily_ritual_repository.dart';
import '../data/leonidas_voice_preference_store.dart';
import '../domain/daily_ritual.dart';
import 'daily_ritual_stage_controller.dart';
import 'ritual_tarot_art.dart';

export '../application/leonidas_voice.dart'
    show LeonidasVoice, PlatformLeonidasVoice;

class LeonidasRitualSequence extends StatefulWidget {
  const LeonidasRitualSequence({
    super.key,
    required this.ritual,
    required this.onReveal,
    this.onComplete,
    this.onShowEvidence,
    this.authorityController,
    this.cacheScope,
    this.voicePreferenceStore,
    this.prepareExactMedia,
    this.monotonicNow,
    this.voice = const PlatformLeonidasVoice(),
    this.useBundledArtwork = true,
    this.assetPackage,
  });

  final DailyRitual ritual;
  final Future<bool> Function() onReveal;
  final Future<bool> Function()? onComplete;
  final VoidCallback? onShowEvidence;
  final DailyRitualController? authorityController;
  final CacheScope? cacheScope;
  final LeonidasVoicePreferencePersistence? voicePreferenceStore;
  final DailyRitualMediaPreparer? prepareExactMedia;
  final DailyRitualMonotonicNow? monotonicNow;
  final LeonidasVoice voice;
  final bool useBundledArtwork;
  final String? assetPackage;

  @override
  State<LeonidasRitualSequence> createState() => _LeonidasRitualSequenceState();
}

class _LeonidasRitualSequenceState extends State<LeonidasRitualSequence>
    with WidgetsBindingObserver {
  static const _revealFailureLine =
      'The card could not be revealed. Your ritual remains safely concealed; try again when you are ready.';

  late DailyRitualStageController _stage;
  _CallbackStageAuthority? _callbackAuthority;
  bool _appResumed = true;
  bool? _lastVisible;

  DailyRitualStagePhase get _phase => _stage.phase;

  bool get _cardRevealed => switch (_phase) {
    DailyRitualStagePhase.revealed ||
    DailyRitualStagePhase.finishPending ||
    DailyRitualStagePhase.finishFailure ||
    DailyRitualStagePhase.closing ||
    DailyRitualStagePhase.completed => true,
    _ => false,
  };

  bool get _showsStanding => switch (_phase) {
    DailyRitualStagePhase.resting ||
    DailyRitualStagePhase.ready ||
    DailyRitualStagePhase.holding ||
    DailyRitualStagePhase.acceptedWaiting ||
    DailyRitualStagePhase.revealFailure ||
    DailyRitualStagePhase.mediaUnavailable => true,
    _ => false,
  };

  bool get _showsCloseUp => switch (_phase) {
    DailyRitualStagePhase.revealed ||
    DailyRitualStagePhase.finishPending ||
    DailyRitualStagePhase.finishFailure ||
    DailyRitualStagePhase.closing ||
    DailyRitualStagePhase.completed => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stage = _createStage();
    unawaited(_stage.restoreVoicePreference());
  }

  @override
  void didUpdateWidget(covariant LeonidasRitualSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorityController != widget.authorityController ||
        oldWidget.cacheScope != widget.cacheScope ||
        oldWidget.voicePreferenceStore != widget.voicePreferenceStore) {
      _stage.dispose();
      _stage = _createStage();
      unawaited(_stage.restoreVoicePreference());
    } else {
      _callbackAuthority?.current = widget.ritual;
      _stage.synchronizeAuthority();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _applyVisibility(
      forcedReason: _appResumed ? null : HoldCancellation.appInactive,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stage.dispose();
    super.dispose();
  }

  String get _finalCaption => dailyRitualClosingCaption(widget.ritual);

  bool get _reducedMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  Duration _motionDuration(int milliseconds) =>
      _reducedMotion ? Duration.zero : Duration(milliseconds: milliseconds);

  DailyRitualStageController _createStage() {
    final controller = widget.authorityController;
    final authority = controller == null
        ? (_callbackAuthority = _CallbackStageAuthority(
            widget.onReveal,
            widget.onComplete,
            current: widget.ritual,
          ))
        : ControllerDailyRitualStageAuthority(controller);
    return DailyRitualStageController(
      authority: authority,
      scope:
          widget.cacheScope ??
          CacheScope(
            accountId: widget.ritual.userId ?? 'unscoped-ritual',
            resetGeneration: widget.ritual.deletionEpoch ?? 0,
          ),
      preferenceStore:
          widget.voicePreferenceStore ?? _EphemeralVoicePreferenceStore(),
      voice: widget.voice,
      prepareExactMedia: _prepareExactMedia,
      monotonicNow: widget.monotonicNow,
    );
  }

  Future<bool> _prepareExactMedia(DailyRitual ritual) async {
    final injected = widget.prepareExactMedia;
    if (injected != null) return injected(ritual);
    if (!widget.useBundledArtwork || !mounted) return false;
    final artwork = resolveRitualTarotArtwork(
      art: ritual.art,
      date: ritual.date,
      mode: ritual.mode,
    );
    if (artwork == null) return false;
    try {
      await precacheImage(
        AssetImage(artwork.assetPath, package: widget.assetPackage),
        context,
      );
      return mounted;
    } on Object {
      return false;
    }
  }

  void _applyVisibility({HoldCancellation? forcedReason}) {
    if (!mounted) return;
    final routeVisible = ModalRoute.of(context)?.isCurrent ?? true;
    final tabVisible = TickerMode.valuesOf(context).enabled;
    final visible = _appResumed && routeVisible && tabVisible;
    if (_lastVisible == visible) return;
    _lastVisible = visible;
    final reason =
        forcedReason ??
        (!routeVisible
            ? HoldCancellation.routeHidden
            : !tabVisible
            ? HoldCancellation.tabHidden
            : HoldCancellation.navigation);
    _stage.setVisible(visible, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    _applyVisibility();
    return ListenableBuilder(
      listenable: _stage,
      builder: (context, _) => _buildStage(context),
    );
  }

  Widget _buildStage(BuildContext context) {
    final colors = context.ritualColors;
    final textScaleGrowth = math.max(
      0.0,
      MediaQuery.textScalerOf(context).scale(16) - 16,
    );
    final stageHeight = 700.0 + math.min(150.0, textScaleGrowth * 7.5);
    final artwork = widget.useBundledArtwork
        ? resolveRitualTarotArtwork(
            art: widget.ritual.art,
            date: widget.ritual.date,
            mode: widget.ritual.mode,
          )
        : null;

    return Semantics(
      container: true,
      label: 'Leonidas Daily Ritual sequence',
      explicitChildNodes: true,
      child: ConstrainedBox(
        key: const Key('leonidas-ritual-sequence'),
        constraints: BoxConstraints(minHeight: stageHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF130C19),
              border: Border.all(color: colors.gold.withValues(alpha: 0.36)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ExcludeSemantics(child: _CelestialBackdrop()),
                ),
                Positioned.fill(
                  child: _LeonidasPortrait(
                    standing: _showsStanding,
                    closeUp: _showsCloseUp,
                    duration: _motionDuration(900),
                    package: widget.assetPackage,
                    useBundledArtwork: widget.useBundledArtwork,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAILY RITUAL',
                              style: TextStyle(
                                color: colors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _phaseLabel,
                              key: const Key('leonidas-phase-label'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label:
                                _stage.voicePreference ==
                                    LeonidasVoicePreference.pending
                                ? 'Leonidas voice unavailable'
                                : 'Leonidas voice',
                            toggled:
                                _stage.voicePreference ==
                                LeonidasVoicePreference.enabled,
                            onTap:
                                _stage.voicePreference ==
                                    LeonidasVoicePreference.pending
                                ? null
                                : () => _stage.setVoiceEnabled(
                                    _stage.voicePreference !=
                                        LeonidasVoicePreference.enabled,
                                  ),
                            child: ExcludeSemantics(
                              child: Switch.adaptive(
                                key: const Key('leonidas-voice-toggle'),
                                value:
                                    _stage.voicePreference ==
                                    LeonidasVoicePreference.enabled,
                                onChanged:
                                    _stage.voicePreference ==
                                        LeonidasVoicePreference.pending
                                    ? null
                                    : _stage.setVoiceEnabled,
                              ),
                            ),
                          ),
                          const Text(
                            'Voice',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 82,
                  left: 0,
                  right: 0,
                  height: 300 + math.min(60, textScaleGrowth * 2),
                  child: AnimatedAlign(
                    duration: _motionDuration(800),
                    curve: Curves.easeOutCubic,
                    alignment: _showsCloseUp
                        ? const Alignment(-0.58, -0.12)
                        : const Alignment(-0.42, -0.1),
                    child: _RitualFlipCard(
                      revealed: _cardRevealed,
                      duration: _motionDuration(1050),
                      artwork: artwork,
                      fallbackAlt: widget.ritual.art.alt,
                      package: widget.assetPackage,
                      colors: colors,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 410 + math.min(80, textScaleGrowth * 3)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showsCloseUp) ...[
                            Text(
                              widget.ritual.marketLabel.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.ritual.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'LibreBaskerville',
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.ritual.interpretation,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _CaptionPanel(
                            caption: _caption,
                            speaking:
                                _phase == DailyRitualStagePhase.closing &&
                                _stage.voicePreference ==
                                    LeonidasVoicePreference.enabled,
                          ),
                          const SizedBox(height: 10),
                          _buildActions(),
                          if (widget.ritual.demo.isDemo) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Demo content · Not live market data · Not a recommendation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _phaseLabel => switch (_phase) {
    DailyRitualStagePhase.resting => 'Awaiting your choice',
    DailyRitualStagePhase.ready => 'Ready to hold',
    DailyRitualStagePhase.holding => 'Hold the seal',
    DailyRitualStagePhase.acceptedWaiting => 'Confirming today’s card',
    DailyRitualStagePhase.revealed => 'Reading revealed',
    DailyRitualStagePhase.finishPending => 'Finishing safely',
    DailyRitualStagePhase.closing => 'Today’s ritual is complete.',
    DailyRitualStagePhase.completed => 'Today’s ritual is complete.',
    DailyRitualStagePhase.revealFailure => 'Reveal paused safely',
    DailyRitualStagePhase.finishFailure => 'Finish paused safely',
    DailyRitualStagePhase.mediaUnavailable => 'Card media unavailable',
  };

  String get _caption => switch (_phase) {
    DailyRitualStagePhase.resting =>
      'Leonidas is ready whenever you choose to begin.',
    DailyRitualStagePhase.ready when _stage.cancellation != null =>
      'You let go. Was the moment not right?',
    DailyRitualStagePhase.ready ||
    DailyRitualStagePhase.holding => 'Place your thumb on the seal and hold.',
    DailyRitualStagePhase.acceptedWaiting =>
      'The seal is set while today’s card is confirmed.',
    DailyRitualStagePhase.revealFailure => _revealFailureLine,
    DailyRitualStagePhase.finishPending =>
      'Your confirmed reading remains here while the ritual finishes.',
    DailyRitualStagePhase.finishFailure =>
      'Your reading is still here. Finish again when you are ready.',
    DailyRitualStagePhase.closing ||
    DailyRitualStagePhase.completed => _finalCaption,
    DailyRitualStagePhase.revealed => 'Take in the reading at your own pace.',
    DailyRitualStagePhase.mediaUnavailable =>
      'The assigned card could not be prepared. Nothing else was substituted.',
  };

  Widget _buildActions() {
    final gold = context.ritualColors.gold;
    if (_phase == DailyRitualStagePhase.resting) {
      return KeyedSubtree(
        key: const Key('ritual-reveal'),
        child: FilledButton.icon(
          key: const Key('leonidas-sequence-start'),
          onPressed: _stage.start,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Start your daily ritual'),
        ),
      );
    }
    if (_phase == DailyRitualStagePhase.ready ||
        _phase == DailyRitualStagePhase.holding ||
        _phase == DailyRitualStagePhase.acceptedWaiting ||
        _phase == DailyRitualStagePhase.revealFailure) {
      return _SealHold(stage: _stage);
    }
    if (_phase == DailyRitualStagePhase.revealed ||
        _phase == DailyRitualStagePhase.finishFailure) {
      return FilledButton.icon(
        key: const Key('ritual-complete'),
        onPressed: _stage.finish,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Finish today’s ritual'),
      );
    }
    if (_phase == DailyRitualStagePhase.finishPending) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_phase == DailyRitualStagePhase.closing) {
      return TextButton(
        key: const Key('leonidas-closing-skip'),
        onPressed: _stage.skipClosing,
        child: const Text('Skip'),
      );
    }
    if (_phase == DailyRitualStagePhase.completed) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (widget.onShowEvidence != null &&
              widget.ritual.evidence.isNotEmpty)
            FilledButton.tonalIcon(
              key: const Key('leonidas-evidence'),
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A101A),
              ),
              onPressed: widget.onShowEvidence,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review evidence'),
            ),
        ],
      );
    }
    return const SizedBox(height: 48);
  }
}

class _SealHold extends StatelessWidget {
  const _SealHold({required this.stage});

  final DailyRitualStageController stage;

  @override
  Widget build(BuildContext context) {
    final assistive = MediaQuery.accessibleNavigationOf(context);
    final active = stage.phase == DailyRitualStagePhase.holding;
    return Semantics(
      label: assistive ? 'Begin ritual' : 'Hold to attune',
      value: '${stage.semanticProgressSeconds} of 5 seconds',
      button: assistive && !active,
      onTap: assistive && !active ? stage.beginSemanticHold : null,
      onDismiss: assistive && active
          ? () => stage.cancel(HoldCancellation.semanticCancel)
          : null,
      child: ExcludeSemantics(
        child: Listener(
          key: const Key('daily-ritual-seal-hit-region'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.buttons == kPrimaryButton) {
              stage.beginPointerHold(event.pointer);
            }
          },
          onPointerMove: (event) {
            if (!stage.ownsPointer(event.pointer)) return;
            const region = Rect.fromLTWH(0, 0, 96, 96);
            if (!region.contains(event.localPosition)) {
              stage.pointerExit(event.pointer);
            }
          },
          onPointerUp: (event) => stage.pointerUp(event.pointer),
          onPointerCancel: (event) => stage.pointerCancel(event.pointer),
          child: SizedBox.square(
            dimension: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 82,
                  child: CircularProgressIndicator(
                    key: const Key('daily-ritual-hold-progress'),
                    value: stage.holdProgress,
                    strokeWidth: 5,
                  ),
                ),
                const Icon(Icons.auto_awesome, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallbackStageAuthority implements DailyRitualStageAuthority {
  _CallbackStageAuthority(
    this._reveal,
    this._complete, {
    required this.current,
  });

  @override
  DailyRitual? current;
  final Future<bool> Function() _reveal;
  final Future<bool> Function()? _complete;

  @override
  bool get mutationAuthorityEnabled => true;

  @override
  Future<void> revalidate() async {}

  @override
  Future<RitualTransitionResult?> reveal() async {
    final before = current;
    if (before == null || !await _reveal()) return null;
    final after = _copyWithState(before, DailyRitualState.revealed);
    current = after;
    return _transitionResult(RitualOperation.reveal, before, after);
  }

  @override
  Future<RitualTransitionResult?> complete() async {
    final before = current;
    if (before == null || _complete == null || !await _complete()) return null;
    final after = _copyWithState(before, DailyRitualState.completed);
    current = after;
    return _transitionResult(RitualOperation.complete, before, after);
  }

  @override
  void invalidateForResume() {}
}

class _EphemeralVoicePreferenceStore
    implements LeonidasVoicePreferencePersistence {
  LeonidasVoicePreference value = LeonidasVoicePreference.enabled;

  @override
  Future<void> clearScope(CacheScope scope) async {
    value = LeonidasVoicePreference.enabled;
  }

  @override
  Future<LeonidasVoicePreference> read(CacheScope scope) async => value;

  @override
  Future<void> write(CacheScope scope, {required bool enabled}) async {
    value = enabled
        ? LeonidasVoicePreference.enabled
        : LeonidasVoicePreference.disabled;
  }
}

RitualTransitionResult _transitionResult(
  RitualOperation operation,
  DailyRitual before,
  DailyRitual after,
) => RitualTransitionResult(
  operation: operation,
  lineage: before.lineage,
  target: operation == RitualOperation.reveal
      ? DailyRitualState.revealed
      : DailyRitualState.completed,
  disposition: RitualOperationDisposition.committed,
  authoritative: after,
);

DailyRitual _copyWithState(DailyRitual source, DailyRitualState state) =>
    DailyRitual(
      assignmentId: source.assignmentId,
      date: source.date,
      mode: source.mode,
      revision: source.revision,
      title: source.title,
      art: source.art,
      interpretation: source.interpretation,
      guidance: source.guidance,
      marketLabel: source.marketLabel,
      ideas: source.ideas,
      evidence: source.evidence,
      rowan: source.rowan,
      version: source.version + 1,
      state: state,
      revealedAt: source.revealedAt ?? DateTime.now().toUtc(),
      completedAt: state == DailyRitualState.completed
          ? DateTime.now().toUtc()
          : null,
      demo: source.demo,
      userId: source.userId,
      deletionEpoch: source.deletionEpoch,
      scheduleId: source.scheduleId,
      serverEvaluatedAt: source.serverEvaluatedAt,
      validUntil: source.validUntil,
      contentIdentity: source.contentIdentity,
      mediaAvailability: source.mediaAvailability,
      contentAvailability: source.contentAvailability,
    );

class _LeonidasPortrait extends StatelessWidget {
  const _LeonidasPortrait({
    required this.standing,
    required this.closeUp,
    required this.duration,
    required this.package,
    required this.useBundledArtwork,
  });

  final bool standing;
  final bool closeUp;
  final Duration duration;
  final String? package;
  final bool useBundledArtwork;

  @override
  Widget build(BuildContext context) {
    Widget portrait = const SizedBox.shrink(key: ValueKey('empty'));
    if (useBundledArtwork && standing) {
      portrait = _portrait(
        key: const Key('leonidas-standing'),
        asset:
            'assets/images/leonidas/leonidas-canonical-observatory-hero-v1.png',
        alignment: const Alignment(0.36, -0.8),
        semanticLabel: 'Leonidas standing in the Candlelit Observatory',
      );
    } else if (useBundledArtwork && closeUp) {
      portrait = _portrait(
        key: const Key('leonidas-close-up'),
        asset:
            'assets/images/leonidas/leonidas-canonical-scholar-portrait-v1.png',
        alignment: const Alignment(0.34, -0.72),
        semanticLabel: 'Close-up of Leonidas interpreting the revealed card',
      );
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.04, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: portrait,
    );
  }

  Widget _portrait({
    required Key key,
    required String asset,
    required Alignment alignment,
    required String semanticLabel,
  }) {
    return Semantics(
      key: key,
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.78, 1],
          ).createShader(bounds),
          child: Image.asset(
            asset,
            package: package,
            fit: BoxFit.cover,
            alignment: alignment,
          ),
        ),
      ),
    );
  }
}

class _RitualFlipCard extends StatelessWidget {
  const _RitualFlipCard({
    required this.revealed,
    required this.duration,
    required this.artwork,
    required this.fallbackAlt,
    required this.package,
    required this.colors,
  });

  final bool revealed;
  final Duration duration;
  final RitualTarotArtwork? artwork;
  final String fallbackAlt;
  final String? package;
  final RitualColors colors;

  @override
  Widget build(BuildContext context) {
    final decodeWidth = (150 * MediaQuery.devicePixelRatioOf(context)).ceil();
    final child = revealed
        ? Semantics(
            key: const Key('leonidas-card-front'),
            image: true,
            label: artwork?.alt ?? fallbackAlt,
            child: ExcludeSemantics(
              child: _cardFrame(
                child: artwork == null
                    ? Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.gold,
                        size: 42,
                      )
                    : Image.asset(
                        artwork!.assetPath,
                        key: const Key('daily-ritual-card-art'),
                        package: package,
                        cacheWidth: decodeWidth,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          )
        : Semantics(
            key: const Key('leonidas-card-back'),
            image: true,
            label: 'Unrevealed ritual card',
            child: ExcludeSemantics(
              child: _cardFrame(
                child: DecoratedBox(
                  key: const Key('daily-ritual-card-back'),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B182D), Color(0xFF160E24)],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.gold.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Text(
                        '♌',
                        style: TextStyle(color: colors.gold, fontSize: 36),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

    return SizedBox(
      width: 150,
      height: 262,
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (transitionChild, animation) {
          return AnimatedBuilder(
            animation: animation,
            child: transitionChild,
            builder: (context, child) {
              final angle = (1 - animation.value) * math.pi;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: child,
              );
            },
          );
        },
        child: child,
      ),
    );
  }

  Widget _cardFrame({required Widget child}) => SizedBox(
    width: 150,
    height: 262,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gold.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(11), child: child),
    ),
  );
}

class _CaptionPanel extends StatelessWidget {
  const _CaptionPanel({required this.caption, required this.speaking});

  final String caption;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final gold = context.ritualColors.gold;
    return Semantics(
      liveRegion: true,
      label: 'Leonidas says: $caption',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE8110A16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: speaking
                        ? gold.withValues(alpha: 0.16)
                        : Colors.transparent,
                    border: Border.all(color: gold.withValues(alpha: 0.56)),
                    boxShadow: speaking
                        ? [
                            BoxShadow(
                              color: gold.withValues(alpha: 0.24),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: gold,
                      fontFamily: 'LibreBaskerville',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEONIDAS',
                        style: TextStyle(
                          color: gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        caption,
                        key: const Key('leonidas-caption'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'LibreBaskerville',
                          fontSize: 14,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CelestialBackdrop extends StatelessWidget {
  const _CelestialBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CelestialPainter(),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF100A17), Color(0xFF3B182D), Color(0xFF100918)],
            stops: [0, 0.64, 1],
          ),
        ),
      ),
    );
  }
}

class _CelestialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.38);
    final ring = Paint()
      ..color = const Color(0x33E5BD6C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in <double>[90, 145, 210]) {
      canvas.drawCircle(center, radius, ring);
    }
    final star = Paint()..color = const Color(0x55FFE3A1);
    const points = <Offset>[
      Offset(0.13, 0.17),
      Offset(0.74, 0.12),
      Offset(0.87, 0.27),
      Offset(0.2, 0.46),
      Offset(0.69, 0.53),
      Offset(0.9, 0.68),
      Offset(0.37, 0.72),
    ];
    for (final point in points) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        1.25,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
