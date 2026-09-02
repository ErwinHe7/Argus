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
import 'daily_ritual_stage_spec.dart';
import 'ritual_tarot_art.dart';

export '../application/leonidas_voice.dart'
    show LeonidasVoice, PlatformLeonidasVoice;

class LeonidasRitualSequence extends StatefulWidget {
  const LeonidasRitualSequence({
    super.key,
    required this.ritual,
    required this.onReveal,
    this.onRevalidate,
    this.onComplete,
    this.onStartRequested,
    this.onShowEvidence,
    this.onOpenStarpath,
    this.authorityController,
    this.cacheScope,
    this.voicePreferenceStore,
    this.prepareExactMedia,
    this.monotonicNow,
    this.voice = const PlatformLeonidasVoice(),
    this.useBundledArtwork = true,
    this.assetPackage,
    this.startImmediately = false,
  });

  final DailyRitual ritual;
  final Future<bool> Function() onReveal;
  final Future<void> Function()? onRevalidate;
  final Future<bool> Function()? onComplete;
  final VoidCallback? onStartRequested;
  final VoidCallback? onShowEvidence;
  final VoidCallback? onOpenStarpath;
  final DailyRitualController? authorityController;
  final CacheScope? cacheScope;
  final LeonidasVoicePreferencePersistence? voicePreferenceStore;
  final DailyRitualMediaPreparer? prepareExactMedia;
  final DailyRitualMonotonicNow? monotonicNow;
  final LeonidasVoice voice;
  final bool useBundledArtwork;
  final String? assetPackage;
  final bool startImmediately;

  @override
  State<LeonidasRitualSequence> createState() => _LeonidasRitualSequenceState();
}

enum _ExactMediaState { loading, ready, unavailable }

class _LeonidasRitualSequenceState extends State<LeonidasRitualSequence>
    with WidgetsBindingObserver {
  static const _revealFailureLine =
      "The ritual could not be opened. Try again when you're ready.";

  late DailyRitualStageController _stage;
  _CallbackStageAuthority? _callbackAuthority;
  RitualTarotArtwork? _artwork;
  AssetImage? _imageProvider;
  String? _mediaIdentity;
  _ExactMediaState _mediaState = _ExactMediaState.unavailable;
  int _mediaAttempt = 0;
  bool _appResumed = true;
  bool? _lastVisible;

  DailyRitualStagePhase get _phase => _stage.phase;
  bool get _reducedMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  bool get _hasExactImage =>
      _artwork != null &&
      _imageProvider != null &&
      _mediaState == _ExactMediaState.ready;
  bool get _cardShouldShow =>
      _hasExactImage &&
      switch (_phase) {
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
    _syncArtwork();
    _stage = _createStage();
    if (widget.startImmediately) _stage.start();
    unawaited(_stage.restoreVoicePreference());
  }

  @override
  void didUpdateWidget(covariant LeonidasRitualSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncArtwork();
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

  void _syncArtwork() {
    final artwork = widget.useBundledArtwork
        ? resolveRitualTarotArtwork(
            art: widget.ritual.art,
            date: widget.ritual.date,
            mode: widget.ritual.mode,
          )
        : null;
    final ritual = widget.ritual;
    final identity = artwork == null
        ? null
        : '${widget.assetPackage ?? ''}:${ritual.userId ?? ''}:'
              '${ritual.deletionEpoch ?? ''}:${ritual.date.toIso8601String()}:'
              '${ritual.mode.name}:${ritual.assignmentId}:'
              '${ritual.revision.id}:${ritual.revision.number}:'
              '${ritual.contentIdentity}:${artwork.key}:'
              '${artwork.assetPath}';
    if (identity == _mediaIdentity) return;
    _artwork = artwork;
    _mediaIdentity = identity;
    _imageProvider = artwork == null
        ? null
        : AssetImage(artwork.assetPath, package: widget.assetPackage);
    _mediaState = artwork == null
        ? _ExactMediaState.unavailable
        : _ExactMediaState.loading;
    _mediaAttempt += 1;
  }

  DailyRitualStageController _createStage() {
    final controller = widget.authorityController;
    final authority = controller == null
        ? (_callbackAuthority = _CallbackStageAuthority(
            widget.onReveal,
            widget.onComplete,
            revalidate: widget.onRevalidate,
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
    final provider = _imageProvider;
    if (provider == null || !mounted) return false;
    try {
      await precacheImage(provider, context);
      if (mounted) _markMediaReady();
      return mounted;
    } on Object {
      if (mounted) _markMediaUnavailable();
      return false;
    }
  }

  void _markMediaReady() {
    if (!mounted || _mediaState == _ExactMediaState.ready) return;
    setState(() => _mediaState = _ExactMediaState.ready);
  }

  void _markMediaUnavailable() {
    if (!mounted || _mediaState == _ExactMediaState.unavailable) return;
    setState(() => _mediaState = _ExactMediaState.unavailable);
  }

  Future<void> _retryExactMedia() async {
    final provider = _imageProvider;
    if (provider == null) {
      setState(() => _mediaState = _ExactMediaState.unavailable);
      return;
    }
    await provider.evict();
    if (!mounted) return;
    setState(() {
      _mediaState = _ExactMediaState.loading;
      _mediaAttempt += 1;
    });
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
    final stageHeight = DailyRitualStageSpec.stageHeight(
      MediaQuery.textScalerOf(context),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    return Semantics(
      container: true,
      label: 'Leonidas Daily Ritual',
      explicitChildNodes: true,
      child: SizedBox(
        key: DailyRitualStageSpec.stageKey,
        width: double.infinity,
        height: stageHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DailyRitualStageSpec.radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0810),
              border: Border.all(color: colors.gold.withValues(alpha: 0.48)),
              borderRadius: BorderRadius.circular(DailyRitualStageSpec.radius),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dx =
                    (constraints.maxWidth -
                        DailyRitualStageSpec.baseStageSize.width) /
                    2;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    const Positioned.fill(
                      child: ExcludeSemantics(child: _StageBackdrop()),
                    ),
                    _positionedRect(
                      DailyRitualStageSpec.portrait.shift(Offset(dx, 0)),
                      child: _LeonidasPortrait(
                        package: widget.assetPackage,
                        useBundledArtwork: widget.useBundledArtwork,
                      ),
                    ),
                    _positionedRect(
                      DailyRitualStageSpec.faceClear.shift(Offset(dx, 0)),
                      child: const IgnorePointer(
                        child: ExcludeSemantics(
                          child: SizedBox(
                            key: DailyRitualStageSpec.faceClearKey,
                          ),
                        ),
                      ),
                    ),
                    _buildCardSurface(dx),
                    _buildMetadata(dx),
                    ..._buildPhaseContent(dx, largeText: largeText),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(double dx) {
    final voicePreference = _stage.voicePreference;
    return Positioned(
      left: DailyRitualStageSpec.metadata.left + dx,
      top: DailyRitualStageSpec.metadata.top,
      width: DailyRitualStageSpec.metadata.width,
      height:
          DailyRitualStageSpec.faceClear.top -
          DailyRitualStageSpec.metadata.top,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY’S DAILY RITUAL',
                    style: TextStyle(
                      color: context.ritualColors.gold,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _phaseLabel,
                    key: const Key('leonidas-phase-label'),
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: DailyRitualStageSpec.voice.width,
              height: 48,
              child: Semantics(
                label: voicePreference == LeonidasVoicePreference.pending
                    ? 'Leonidas voice unavailable'
                    : 'Leonidas voice',
                button: true,
                enabled: voicePreference != LeonidasVoicePreference.pending,
                toggled: voicePreference == LeonidasVoicePreference.enabled,
                onTap: voicePreference == LeonidasVoicePreference.pending
                    ? null
                    : () => _stage.setVoiceEnabled(
                        voicePreference != LeonidasVoicePreference.enabled,
                      ),
                child: ExcludeSemantics(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: DailyRitualStageSpec.voice.width,
                      height: DailyRitualStageSpec.voice.height,
                      child: OutlinedButton(
                        key: const Key('leonidas-voice-toggle'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(76, 44),
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: context.ritualColors.gold.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed:
                            voicePreference == LeonidasVoicePreference.pending
                            ? null
                            : () => _stage.setVoiceEnabled(
                                voicePreference !=
                                    LeonidasVoicePreference.enabled,
                              ),
                        child: Text(
                          voicePreference == LeonidasVoicePreference.enabled
                              ? 'Voice on'
                              : 'Voice off',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSurface(double dx) {
    final provider = _imageProvider;
    if (provider == null || _artwork == null) {
      return const SizedBox.shrink();
    }
    final rect = _cardRect.shift(Offset(dx, 0));
    final positionDuration = _reducedMotion ? Duration.zero : _cardDuration;
    final opacityDuration = DailyRitualStageSpec.motion(
      _cardDuration,
      reducedMotion: _reducedMotion,
    );
    return AnimatedPositioned(
      key: DailyRitualStageSpec.cardSurfaceKey,
      duration: positionDuration,
      curve: DailyRitualStageSpec.enterCurve,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: opacityDuration,
          curve: DailyRitualStageSpec.enterCurve,
          opacity: _cardShouldShow ? 1 : 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: _ExactCardFrame(
                  provider: provider,
                  attempt: _mediaAttempt,
                  colors: context.ritualColors,
                  onReady: _markMediaReady,
                  onUnavailable: _markMediaUnavailable,
                ),
              ),
              if (_cardShouldShow)
                Semantics(
                  key: const Key('leonidas-card-front'),
                  image: true,
                  label: _artwork!.alt,
                  child: const SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Rect get _cardRect => switch (_phase) {
    DailyRitualStagePhase.closing => DailyRitualStageSpec.c2Card,
    DailyRitualStagePhase.completed => DailyRitualStageSpec.keepsakeCard,
    _ => DailyRitualStageSpec.revealedCard,
  };

  Duration get _cardDuration => switch (_phase) {
    DailyRitualStagePhase.closing => DailyRitualStageSpec.c2Expand,
    DailyRitualStagePhase.completed => DailyRitualStageSpec.c2Settle,
    _ => DailyRitualStageSpec.reveal,
  };

  List<Widget> _buildPhaseContent(
    double dx, {
    required bool largeText,
  }) => switch (_phase) {
    DailyRitualStagePhase.resting => _buildResting(dx, largeText: largeText),
    DailyRitualStagePhase.ready ||
    DailyRitualStagePhase.holding ||
    DailyRitualStagePhase.acceptedWaiting ||
    DailyRitualStagePhase.revealFailure => _buildSeal(dx, largeText: largeText),
    DailyRitualStagePhase.revealed ||
    DailyRitualStagePhase.finishPending ||
    DailyRitualStagePhase.finishFailure => _buildReading(
      dx,
      largeText: largeText,
    ),
    DailyRitualStagePhase.closing => _buildClosing(dx),
    DailyRitualStagePhase.completed => _buildCompleted(
      dx,
      largeText: largeText,
    ),
    DailyRitualStagePhase.mediaUnavailable => _buildMediaUnavailable(
      dx,
      completed: widget.ritual.state == DailyRitualState.completed,
    ),
  };

  List<Widget> _buildResting(double dx, {required bool largeText}) {
    if (_imageProvider == null) return _buildMediaUnavailable(dx);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (largeText)
          const Text(
            'Your ritual is ready when you are.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'LibreBaskerville',
              fontSize: 16,
              height: 1.3,
            ),
          )
        else
          const SizedBox(
            height: 48,
            child: Center(
              child: Text(
                'Your ritual is ready when you are.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'LibreBaskerville',
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ),
        SizedBox(height: largeText ? 20 : 23),
        _GoldAction(
          key: const Key('leonidas-sequence-start'),
          label: 'Start your daily ritual',
          onPressed: widget.onStartRequested ?? _stage.start,
        ),
      ],
    );
    return [
      _positionedRect(
        DailyRitualStageSpec.restingSealVisual.shift(Offset(dx, 0)),
        child: const _RestingSeal(),
      ),
      Positioned(
        left: 16 + dx,
        right: math.max(16 - dx, 16),
        top: largeText ? 476 : DailyRitualStageSpec.restingGuidance.top,
        child: AnimatedSwitcher(
          duration: DailyRitualStageSpec.motion(
            DailyRitualStageSpec.startTransition,
            reducedMotion: _reducedMotion,
          ),
          child: content,
        ),
      ),
    ];
  }

  List<Widget> _buildSeal(double dx, {required bool largeText}) {
    final holding =
        _phase == DailyRitualStagePhase.holding ||
        _phase == DailyRitualStagePhase.acceptedWaiting;
    final sealRect = holding
        ? DailyRitualStageSpec.holdingSealHit
        : DailyRitualStageSpec.restingSealHit;
    Widget caption() => Text(
      _sealCaption,
      key: const Key('leonidas-caption'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
    );
    return [
      _positionedRect(
        sealRect.shift(Offset(dx, 0)),
        child: _SealHold(stage: _stage, expanded: holding),
      ),
      Positioned(
        left: 20 + dx,
        right: math.max(20 - dx, 20),
        top: largeText ? 470 : 468,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Text(
                _sealHeading,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.ritualColors.gold,
                  fontFamily: 'LibreBaskerville',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            if (_phase == DailyRitualStagePhase.holding)
              ValueListenableBuilder<double>(
                valueListenable: _stage.holdProgressListenable,
                builder: (context, progress, child) => caption(),
              )
            else
              caption(),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildReading(double dx, {required bool largeText}) {
    if (!_hasExactImage) {
      return _buildMediaUnavailable(dx, completed: false);
    }
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.ritual.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'LibreBaskerville',
            fontSize: 23,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.ritual.interpretation,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        if (_phase == DailyRitualStagePhase.finishFailure) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              'Your reading is still here. Finish again when you are ready.',
              key: Key('daily-ritual-finish-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFFFD6D6), fontSize: 12),
            ),
          ),
        ],
      ],
    );
    if (largeText) {
      return [
        Positioned(
          key: DailyRitualStageSpec.readingContentKey,
          left: 16 + dx,
          right: math.max(16 - dx, 16),
          top: DailyRitualStageSpec.revealedContent.top,
          bottom: 10,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                copy,
                const SizedBox(height: 18),
                _buildFinishAction(),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      _positionedRect(
        DailyRitualStageSpec.revealedContent.shift(Offset(dx, 0)),
        child: KeyedSubtree(
          key: DailyRitualStageSpec.readingContentKey,
          child: ClipRect(child: copy),
        ),
      ),
      _positionedRect(
        DailyRitualStageSpec.revealedFinish.shift(Offset(dx, 0)),
        child: _buildFinishAction(),
      ),
    ];
  }

  Widget _buildFinishAction() {
    if (_phase == DailyRitualStagePhase.finishPending) {
      return SizedBox(
        key: const Key('ritual-complete'),
        height: 52,
        child: Center(
          child: Semantics(
            label: 'Finishing today’s ritual',
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return _GoldAction(
      key: const Key('ritual-complete'),
      label: 'Finish today’s ritual',
      onPressed: _stage.finish,
    );
  }

  List<Widget> _buildClosing(double dx) => [
    Positioned(
      key: DailyRitualStageSpec.c2CaptionKey,
      left: DailyRitualStageSpec.c2Caption.left + dx,
      right: math.max(20 - dx, 20),
      top: DailyRitualStageSpec.c2Caption.top,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              dailyRitualClosingCaption,
              key: const Key('leonidas-caption'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'LibreBaskerville',
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            key: const Key('leonidas-closing-skip'),
            style: TextButton.styleFrom(
              minimumSize: const Size(56, 44),
              foregroundColor: context.ritualColors.gold,
            ),
            onPressed: _stage.skipClosing,
            child: const Text('Skip'),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _buildCompleted(double dx, {required bool largeText}) {
    if (!_hasExactImage) return _buildMediaUnavailable(dx, completed: true);
    final copy = Column(
      key: DailyRitualStageSpec.completedCopyKey,
      crossAxisAlignment: largeText
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          widget.ritual.title,
          textAlign: largeText ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'LibreBaskerville',
            fontSize: 23,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.ritual.interpretation,
          textAlign: largeText ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
    if (!largeText) {
      return [
        _positionedRect(
          DailyRitualStageSpec.keepsakeCopy.shift(Offset(dx, 0)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: DailyRitualStageSpec.keepsakeCopy.width,
              child: copy,
            ),
          ),
        ),
        if (widget.onShowEvidence != null)
          _positionedRect(
            DailyRitualStageSpec.evidenceAction.shift(Offset(dx, 0)),
            child: _GoldAction(
              key: DailyRitualStageSpec.evidenceKey,
              label: 'Review evidence',
              onPressed: widget.onShowEvidence!,
            ),
          ),
        if (widget.onOpenStarpath != null)
          _positionedRect(
            DailyRitualStageSpec.starpathAction.shift(Offset(dx, 0)),
            child: _OutlineAction(
              key: DailyRitualStageSpec.starpathKey,
              label: 'Continue to Starpath',
              onPressed: widget.onOpenStarpath!,
            ),
          ),
      ];
    }
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 118, height: 206),
        const SizedBox(height: 12),
        copy,
        const SizedBox(height: 20),
        ..._onwardActions(),
      ],
    );
    return [
      Positioned(
        left: 16 + dx,
        right: math.max(16 - dx, 16),
        top: DailyRitualStageSpec.keepsakeCard.top,
        bottom: 10,
        child: SingleChildScrollView(
          key: const Key('daily-ritual-accessibility-scroll'),
          child: content,
        ),
      ),
    ];
  }

  List<Widget> _onwardActions() => [
    if (widget.onShowEvidence != null)
      _GoldAction(
        key: DailyRitualStageSpec.evidenceKey,
        label: 'Review evidence',
        onPressed: widget.onShowEvidence!,
      ),
    if (widget.onShowEvidence != null && widget.onOpenStarpath != null)
      const SizedBox(height: 10),
    if (widget.onOpenStarpath != null)
      _OutlineAction(
        key: DailyRitualStageSpec.starpathKey,
        label: 'Continue to Starpath',
        onPressed: widget.onOpenStarpath!,
      ),
  ];

  List<Widget> _buildMediaUnavailable(double dx, {bool completed = false}) => [
    Positioned(
      left: 20 + dx,
      right: math.max(20 - dx, 20),
      top: completed ? 272 : 442,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ExactMediaUnavailable(
            loading: _mediaState == _ExactMediaState.loading,
            onRetry: _retryExactMedia,
          ),
          if (completed) ...[const SizedBox(height: 18), ..._onwardActions()],
        ],
      ),
    ),
  ];

  String get _phaseLabel => switch (_phase) {
    DailyRitualStagePhase.resting => 'Awaiting your choice',
    DailyRitualStagePhase.ready => 'Ready to hold',
    DailyRitualStagePhase.holding => 'Hold the seal',
    DailyRitualStagePhase.acceptedWaiting => 'Confirming today’s card',
    DailyRitualStagePhase.revealed => 'Reading revealed',
    DailyRitualStagePhase.finishPending => 'Finishing safely',
    DailyRitualStagePhase.closing ||
    DailyRitualStagePhase.completed => 'Today’s ritual is complete.',
    DailyRitualStagePhase.revealFailure => 'Reveal paused safely',
    DailyRitualStagePhase.finishFailure => 'Finish paused safely',
    DailyRitualStagePhase.mediaUnavailable => 'Exact card unavailable',
  };

  String get _sealHeading => switch (_phase) {
    DailyRitualStagePhase.acceptedWaiting => 'The seal is set',
    DailyRitualStagePhase.revealFailure => 'Try again',
    _ => 'Hold to attune',
  };

  String get _sealCaption => switch (_phase) {
    DailyRitualStagePhase.ready when _stage.cancellation != null =>
      'You let go. Was the moment not right?',
    DailyRitualStagePhase.holding =>
      'Stay with me. ${_stage.semanticProgressSeconds} of 5 seconds.',
    DailyRitualStagePhase.acceptedWaiting =>
      'Today’s exact card is being confirmed.',
    DailyRitualStagePhase.revealFailure => _revealFailureLine,
    _ => 'Place your thumb on the seal and hold.',
  };
}

class _LeonidasPortrait extends StatelessWidget {
  const _LeonidasPortrait({
    required this.package,
    required this.useBundledArtwork,
  });

  final String? package;
  final bool useBundledArtwork;

  @override
  Widget build(BuildContext context) {
    if (!useBundledArtwork) {
      return const SizedBox(key: DailyRitualStageSpec.portraitKey);
    }
    return Semantics(
      key: DailyRitualStageSpec.portraitKey,
      image: true,
      label: 'Leonidas guiding today’s ritual',
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
            'assets/images/leonidas/leonidas-canonical-scholar-portrait-v1.png',
            package: package,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}

class _RestingSeal extends StatelessWidget {
  const _RestingSeal();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: DecoratedBox(
        key: DailyRitualStageSpec.sealVisualKey,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF5A3812), Color(0xFF211221)],
          ),
          border: Border.all(
            color: context.ritualColors.gold.withValues(alpha: 0.72),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.auto_awesome,
            color: context.ritualColors.gold,
            size: 42,
          ),
        ),
      ),
    ),
  );
}

class _SealHold extends StatelessWidget {
  const _SealHold({required this.stage, required this.expanded});

  final DailyRitualStageController stage;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: stage.holdProgressListenable,
      builder: (context, progress, _) {
        final assistive = MediaQuery.accessibleNavigationOf(context);
        final active = stage.phase == DailyRitualStagePhase.holding;
        final visualDimension = expanded ? 150.0 : 130.0;
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
              key: DailyRitualStageSpec.sealHitKey,
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (event.buttons == kPrimaryButton) {
                  stage.beginPointerHold(event.pointer);
                }
              },
              onPointerMove: (event) {
                if (!stage.ownsPointer(event.pointer)) return;
                final region = Offset.zero & Size.square(expanded ? 180 : 160);
                if (!region.contains(event.localPosition)) {
                  stage.pointerExit(event.pointer);
                }
              },
              onPointerUp: (event) => stage.pointerUp(event.pointer),
              onPointerCancel: (event) => stage.pointerCancel(event.pointer),
              child: Center(
                child: AnimatedContainer(
                  key: DailyRitualStageSpec.sealVisualKey,
                  duration: DailyRitualStageSpec.holdCompression,
                  width: visualDimension,
                  height: visualDimension,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF714819), Color(0xFF251323)],
                    ),
                    border: Border.all(
                      color: context.ritualColors.gold,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: visualDimension - 10,
                        child: CircularProgressIndicator(
                          key: const Key('daily-ritual-hold-progress'),
                          value: progress,
                          strokeWidth: 7,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFFFFD98A),
                        ),
                      ),
                      Icon(
                        Icons.auto_awesome,
                        color: const Color(0xFFFFD98A),
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExactCardFrame extends StatelessWidget {
  const _ExactCardFrame({
    required this.provider,
    required this.attempt,
    required this.colors,
    required this.onReady,
    required this.onUnavailable,
  });

  final ImageProvider provider;
  final int attempt;
  final RitualColors colors;
  final VoidCallback onReady;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF0A070C),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: colors.gold, width: 2),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: _ExactCardImage(
        key: ValueKey(attempt),
        provider: provider,
        onReady: onReady,
        onUnavailable: onUnavailable,
      ),
    ),
  );
}

class _ExactCardImage extends StatefulWidget {
  const _ExactCardImage({
    super.key,
    required this.provider,
    required this.onReady,
    required this.onUnavailable,
  });

  final ImageProvider provider;
  final VoidCallback onReady;
  final VoidCallback onUnavailable;

  @override
  State<_ExactCardImage> createState() => _ExactCardImageState();
}

class _ExactCardImageState extends State<_ExactCardImage> {
  bool _reported = false;

  void _report(VoidCallback callback) {
    if (_reported) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  @override
  Widget build(BuildContext context) => Image(
    key: DailyRitualStageSpec.cardArtKey,
    image: widget.provider,
    fit: BoxFit.contain,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) _report(widget.onReady);
      return child;
    },
    errorBuilder: (context, error, stackTrace) {
      _report(widget.onUnavailable);
      return const SizedBox.expand();
    },
  );
}

class _ExactMediaUnavailable extends StatelessWidget {
  const _ExactMediaUnavailable({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: loading
        ? 'Preparing the exact assigned card'
        : 'The exact assigned card is unavailable',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          Icon(Icons.hourglass_top_rounded, color: context.ritualColors.gold)
        else
          Icon(Icons.broken_image_outlined, color: context.ritualColors.gold),
        const SizedBox(height: 8),
        Text(
          loading ? 'Preparing today’s exact card…' : 'Today’s exact card is unavailable. Nothing else was substituted.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, height: 1.3),
        ),
        if (!loading) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('daily-ritual-media-retry'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: context.ritualColors.gold,
            ),
            onPressed: onRetry,
            child: const Text('Retry exact card'),
          ),
        ],
      ],
    ),
  );
}

class _GoldAction extends StatelessWidget {
  const _GoldAction({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: context.ritualColors.gold,
        foregroundColor: const Color(0xFF1B101A),
        textStyle: const TextStyle(
          fontFamily: 'LibreBaskerville',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: context.ritualColors.gold,
        side: BorderSide(color: context.ritualColors.gold),
        textStyle: const TextStyle(
          fontFamily: 'LibreBaskerville',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class _StageBackdrop extends StatelessWidget {
  const _StageBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF09070D), Color(0xFF1C111E), Color(0xFF08070A)],
        stops: [0, 0.58, 1],
      ),
    ),
  );
}

Widget _positionedRect(Rect rect, {required Widget child}) => Positioned(
  left: rect.left,
  top: rect.top,
  width: rect.width,
  height: rect.height,
  child: child,
);

class _CallbackStageAuthority implements DailyRitualStageAuthority {
  _CallbackStageAuthority(
    this._reveal,
    this._complete, {
    this._revalidate,
    required this.current,
  });

  @override
  DailyRitual? current;
  final Future<bool> Function() _reveal;
  final Future<bool> Function()? _complete;
  final Future<void> Function()? _revalidate;

  @override
  bool get mutationAuthorityEnabled => true;

  @override
  Future<void> revalidate() async => _revalidate?.call();

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
