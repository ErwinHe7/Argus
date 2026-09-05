import 'dart:async';

import 'package:flutter/material.dart';

import '../application/leonidas_story_playback.dart';
import '../application/starpath_narration_controller.dart';
import '../domain/leonidas_story.dart';

/// An observatory stage, followed by the learner's readable dialogue and
/// choices. Portrait and controls occupy separate regions at every text scale.
class LeonidasStoryScreen extends StatefulWidget {
  const LeonidasStoryScreen({
    super.key,
    required this.playback,
    required this.narrationPreference,
    required this.narrationEngineFactory,
    required this.onNotes,
    required this.onContinue,
    required this.continueLabel,
    this.onCheck,
  });

  final LeonidasStoryPlayback playback;
  final StarpathNarrationPreference narrationPreference;
  final StarpathNarrationEngineFactory narrationEngineFactory;
  final Future<void> Function() onNotes;
  final Future<void> Function() onContinue;
  final Future<void> Function()? onCheck;
  final String continueLabel;

  @override
  State<LeonidasStoryScreen> createState() => _LeonidasStoryScreenState();
}

class _LeonidasStoryScreenState extends State<LeonidasStoryScreen>
    with WidgetsBindingObserver {
  late final StarpathNarrationController _voice;
  final _scroll = ScrollController();
  final _dialogueFocus = FocusNode();
  bool _busy = false;
  bool _foreground = true;
  int _transition = 0;
  LeonidasStoryPlayback get playback => widget.playback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = StarpathNarrationController(
      widget.narrationEngineFactory(),
      script: '',
    );
    widget.narrationPreference.addListener(_preferenceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speakCurrent());
    });
  }

  Future<void> _speakCurrent() async {
    if (!mounted || _busy || !_foreground || widget.narrationPreference.muted) {
      return;
    }
    await _voice.play(text: playback.feedback ?? playback.beat.line);
  }

  void _preferenceChanged() {
    if (mounted) setState(() {});
    if (widget.narrationPreference.muted) {
      unawaited(_voice.stop());
    } else {
      unawaited(_speakCurrent());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      _transition++;
      unawaited(_voice.stop());
    }
  }

  Future<void> _change(VoidCallback change, {bool resetScroll = true}) async {
    if (_busy) return;
    final transition = ++_transition;
    setState(() => _busy = true);
    await _voice.stop();
    if (!mounted) return;
    setState(() {
      change();
      _busy = false;
    });
    if (resetScroll && _scroll.hasClients) _scroll.jumpTo(0);
    if (resetScroll) _dialogueFocus.requestFocus();
    if (transition == _transition) await _speakCurrent();
  }

  Future<void> _leave(Future<void> Function() action) async {
    if (_busy) return;
    _transition++;
    setState(() => _busy = true);
    await _voice.stop();
    if (!mounted) return;
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _transition++;
    WidgetsBinding.instance.removeObserver(this);
    widget.narrationPreference.removeListener(_preferenceChanged);
    _voice.dispose();
    _scroll.dispose();
    _dialogueFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_voice.stop());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(playback.story.lessonTitle),
          actions: [
            ListenableBuilder(
              listenable: widget.narrationPreference,
              builder: (context, _) => IconButton(
                tooltip: widget.narrationPreference.muted
                    ? 'Unmute Leonidas'
                    : 'Mute Leonidas',
                onPressed: widget.narrationPreference.toggle,
                icon: Icon(
                  widget.narrationPreference.muted
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Story options',
              onSelected: (value) {
                if (value == 'replay') {
                  unawaited(_change(playback.replay));
                } else {
                  unawaited(_leave(widget.onNotes));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'replay', child: Text('Replay chapter')),
                PopupMenuItem(value: 'notes', child: Text('Lesson notes')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
              final portrait = _PortraitStage(
                key: ValueKey(playback.story.id),
                storyId: playback.story.id,
                expression: playback.retry
                    ? StoryExpression.concerned
                    : playback.beat.expression,
                setting: playback.story.setting,
              );
              final dialogue = ListView(
                key: const Key('leonidas-story-dialogue'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                children: [
                  Text(
                    playback.story.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The Observatory’s First Light · Scene ${playback.index + 1} of ${playback.story.beats.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Focus(
                    focusNode: _dialogueFocus,
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Leonidas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playback.beat.line,
                    key: const Key('leonidas-story-line'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      height: 1.55,
                    ),
                  ),
                  if (playback.beat.options.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(switch (playback.beat.interaction) {
                      StoryInteraction.inspect =>
                        'Explore every label to continue.',
                      StoryInteraction.sequence => 'Tap each stop in order.',
                      _ => 'Choose your response.',
                    }, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    for (var i = 0; i < playback.beat.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton.icon(
                          key: Key('story-option-$i'),
                          onPressed: _busy
                              ? null
                              : () => _change(
                                  () => playback.select(i),
                                  resetScroll: false,
                                ),
                          icon: Icon(
                            playback.seen.contains(i) ||
                                    playback.selectedAnswer == i
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(playback.beat.options[i].label),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                  ],
                  if (playback.feedback case final feedback?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playback.retry
                                ? 'Let’s look again'
                                : 'Leonidas responds',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feedback,
                            key: const Key('story-feedback'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (playback.atEnd && widget.onCheck != null) ...[
                    FilledButton.tonal(
                      key: const Key('story-knowledge-check'),
                      onPressed: _busy ? null : () => _leave(widget.onCheck!),
                      child: const Text('Open knowledge check'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    key: const Key('story-next'),
                    onPressed: _busy || !playback.canAdvance
                        ? null
                        : playback.atEnd
                        ? () => _leave(widget.onContinue)
                        : () => _change(playback.next),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(playback.atEnd ? widget.continueLabel : 'Next'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        key: const Key('story-back'),
                        onPressed: _busy || playback.index == 0
                            ? null
                            : () => _change(playback.back),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _leave(widget.onNotes),
                        child: const Text('Lesson notes'),
                      ),
                      TextButton.icon(
                        onPressed: _busy || widget.narrationPreference.muted
                            ? null
                            : () => _change(() {}, resetScroll: false),
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Hear again'),
                      ),
                    ],
                  ),
                  ListenableBuilder(
                    listenable: _voice,
                    builder: (context, _) =>
                        _voice.phase == StarpathNarrationPhase.failure ||
                            _voice.phase == StarpathNarrationPhase.unavailable
                        ? const Text(
                            'Voice is unavailable. You can keep reading or try Hear again.',
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: portrait),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: dialogue,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(
                    height: (constraints.maxHeight * (largeText ? .23 : .34))
                        .clamp(100.0, 290.0),
                    width: double.infinity,
                    child: portrait,
                  ),
                  Expanded(child: dialogue),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PortraitStage extends StatefulWidget {
  const _PortraitStage({
    super.key,
    required this.storyId,
    required this.expression,
    required this.setting,
  });
  final String storyId;
  final StoryExpression expression;
  final String setting;

  @override
  State<_PortraitStage> createState() => _PortraitStageState();
}

class _PortraitStageState extends State<_PortraitStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _camera;
  bool _sceneReady = false;
  bool _sceneUnavailable = false;
  bool _paused = false;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _camera = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncMotion();
  }

  @override
  void didUpdateWidget(_PortraitStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId != widget.storyId) {
      _sceneReady = false;
      _sceneUnavailable = false;
      _camera.reset();
      _syncMotion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final shouldMove =
        widget.storyId == 'garden-v1' &&
        _sceneReady &&
        !_sceneUnavailable &&
        !_paused &&
        !_reducedMotion &&
        _tickerEnabled &&
        _foreground;
    if (shouldMove && !_camera.isAnimating) {
      _camera.repeat(reverse: true);
    } else if (!shouldMove) {
      _camera.stop();
    }
  }

  void _sceneLoaded() {
    if (_sceneReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sceneReady || _sceneUnavailable) return;
      setState(() => _sceneReady = true);
      _syncMotion();
    });
  }

  void _sceneFailed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sceneUnavailable) return;
      setState(() => _sceneUnavailable = true);
      _syncMotion();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storyId != 'garden-v1' || _sceneUnavailable) {
      return _semanticArt(_portrait());
    }
    return ColoredBox(
      color: const Color(0xFF0B0310),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 160;
          final captionStyle = Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: const Color(0xFFF6ECF7));
          final captionWidth =
              TextPainter.computeWidth(
                text: TextSpan(text: 'Leonidas', style: captionStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              ) +
              12;
          final portraitWidth = (constraints.maxHeight * .48).clamp(
            86.0,
            132.0,
          );
          final insetWidth =
              (portraitWidth > captionWidth ? portraitWidth : captionWidth)
                  .clamp(86.0, constraints.maxWidth * .42);
          final insetHeight = (constraints.maxHeight * .74).clamp(72.0, 208.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              _semanticArt(
                Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: AnimatedBuilder(
                        animation: _camera,
                        child: Image.asset(
                          'assets/images/leonidas/leonidas-garden-blender-v1.png',
                          key: const Key('leonidas-garden-scene'),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          frameBuilder: (context, child, frame, synchronous) {
                            if (frame != null) _sceneLoaded();
                            return child;
                          },
                          errorBuilder: (_, error, stack) {
                            _sceneFailed();
                            return _portrait();
                          },
                        ),
                        builder: (context, child) => Transform.scale(
                          key: const Key('leonidas-garden-camera'),
                          scale: _reducedMotion
                              ? 1.015
                              : 1.015 +
                                    .025 *
                                        Curves.easeInOutSine.transform(
                                          _camera.value,
                                        ),
                          child: child,
                        ),
                      ),
                    ),
                    Positioned(
                      left: compact ? 8 : 16,
                      bottom: compact ? 8 : 16,
                      width: insetWidth,
                      height: insetHeight,
                      child: DecoratedBox(
                        key: const Key('leonidas-speaker-portrait'),
                        decoration: BoxDecoration(
                          color: const Color(0xFF170F19),
                          border: Border.all(color: const Color(0xFF9B7950)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Column(
                            children: [
                              Expanded(child: _portrait(fit: BoxFit.cover)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Text(
                                  'Leonidas',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: captionStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_sceneReady && !_reducedMotion)
                Positioned(
                  right: compact ? 8 : 16,
                  bottom: compact ? 8 : 16,
                  child: IconButton.filled(
                    key: const Key('leonidas-scene-motion'),
                    tooltip: _paused
                        ? 'Resume scene motion'
                        : 'Pause scene motion',
                    onPressed: () {
                      setState(() => _paused = !_paused);
                      _syncMotion();
                    },
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      backgroundColor: const Color(0xFF170F19),
                      foregroundColor: const Color(0xFFF6ECF7),
                    ),
                    icon: Icon(
                      _paused
                          ? Icons.play_arrow_outlined
                          : Icons.pause_outlined,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _semanticArt(Widget child) => ColoredBox(
    color: const Color(0xFF0B0310),
    child: Semantics(
      label: 'Leonidas in ${widget.setting}',
      image: true,
      child: ExcludeSemantics(child: child),
    ),
  );

  Widget _portrait({BoxFit fit = BoxFit.contain}) {
    final asset = switch (widget.expression) {
      StoryExpression.warm => 'warm-reassurance',
      StoryExpression.playful => 'playful-amusement',
      StoryExpression.analytical => 'analytical-focus',
      StoryExpression.concerned => 'gentle-concern',
    };
    return AnimatedSwitcher(
      duration: _reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: Image.asset(
        'assets/images/leonidas/leonidas-emotion-$asset-v1.png',
        key: ValueKey(asset),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, error, stack) => const Center(
          child: Text('Leonidas', style: TextStyle(color: Color(0xFFF6ECF7))),
        ),
      ),
    );
  }
}
