import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/leonidas_voice.dart';
import '../domain/daily_ritual.dart';
import 'ritual_tarot_art.dart';

export '../application/leonidas_voice.dart'
    show LeonidasVoice, PlatformLeonidasVoice;

enum _LeonidasPhase {
  idle,
  standing,
  summoning,
  revealing,
  closeUp,
  complete,
  revealFailure,
}

class LeonidasRitualSequence extends StatefulWidget {
  const LeonidasRitualSequence({
    super.key,
    required this.ritual,
    required this.onReveal,
    this.onShowEvidence,
    this.voice = const PlatformLeonidasVoice(),
    this.useBundledArtwork = true,
    this.assetPackage,
  });

  final DailyRitual ritual;
  final Future<bool> Function() onReveal;
  final VoidCallback? onShowEvidence;
  final LeonidasVoice voice;
  final bool useBundledArtwork;
  final String? assetPackage;

  @override
  State<LeonidasRitualSequence> createState() => _LeonidasRitualSequenceState();
}

class _LeonidasRitualSequenceState extends State<LeonidasRitualSequence> {
  static const _openingLine =
      'Come closer. We will let the card speak before we ask the evidence to agree.';
  static const _revealFailureLine =
      'The card could not be revealed. Your ritual remains safely concealed; try again when you are ready.';

  late _LeonidasPhase _phase;
  late String _caption;
  bool _voiceEnabled = true;
  bool _running = false;
  int _runToken = 0;

  bool get _wasAlreadyRevealed =>
      widget.ritual.state == DailyRitualState.revealed ||
      widget.ritual.state == DailyRitualState.completed;

  bool get _cardRevealed => switch (_phase) {
    _LeonidasPhase.revealing ||
    _LeonidasPhase.closeUp ||
    _LeonidasPhase.complete => true,
    _ => false,
  };

  bool get _showsStanding => switch (_phase) {
    _LeonidasPhase.idle ||
    _LeonidasPhase.standing ||
    _LeonidasPhase.summoning ||
    _LeonidasPhase.revealing ||
    _LeonidasPhase.revealFailure => true,
    _ => false,
  };

  bool get _showsCloseUp => switch (_phase) {
    _LeonidasPhase.closeUp || _LeonidasPhase.complete => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _phase = _wasAlreadyRevealed
        ? _LeonidasPhase.complete
        : _LeonidasPhase.idle;
    _caption = _wasAlreadyRevealed
        ? _finalCaption
        : 'Leonidas is waiting to begin tonight’s ritual.';
  }

  @override
  void didUpdateWidget(covariant LeonidasRitualSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ritual.assignmentId != widget.ritual.assignmentId) {
      _cancelRun();
      _phase = _wasAlreadyRevealed
          ? _LeonidasPhase.complete
          : _LeonidasPhase.idle;
      _caption = _wasAlreadyRevealed
          ? _finalCaption
          : 'Leonidas is waiting to begin tonight’s ritual.';
      return;
    }
    if (!_running &&
        oldWidget.ritual.state == DailyRitualState.assigned &&
        _wasAlreadyRevealed) {
      _phase = _LeonidasPhase.complete;
      _caption = _finalCaption;
    }
  }

  @override
  void dispose() {
    _cancelRun();
    super.dispose();
  }

  String get _interpretationScript => [
    widget.ritual.title,
    widget.ritual.interpretation,
    _finalCaption,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  String get _finalCaption => [
    widget.ritual.rowan.body,
    widget.ritual.rowan.riskFooter,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  bool get _reducedMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  Duration _motionDuration(int milliseconds) =>
      _reducedMotion ? Duration.zero : Duration(milliseconds: milliseconds);

  Future<bool> _pause(int milliseconds, int token) async {
    await Future<void>.delayed(
      _reducedMotion
          ? const Duration(milliseconds: 1)
          : Duration(milliseconds: milliseconds),
    );
    return mounted && token == _runToken;
  }

  Future<bool> _narrate(String text, int token) async {
    if (!mounted || token != _runToken) return false;
    setState(() => _caption = text);
    if (!_voiceEnabled) {
      return _pause(math.max(1200, text.length * 32), token);
    }
    var spoken = false;
    try {
      spoken = await widget.voice
          .speak(text)
          .timeout(
            Duration(
              milliseconds: math.min(
                120000,
                math.max(12000, text.length * 100),
              ),
            ),
          );
    } on TimeoutException {
      unawaited(widget.voice.stop());
    } on Object {
      // Native speech is optional; the complete caption remains authoritative.
    }
    if (!mounted || token != _runToken) return false;
    if (spoken) return true;
    return _pause(math.max(1200, text.length * 32), token);
  }

  void _setPhase(_LeonidasPhase phase, String caption) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _caption = caption;
    });
  }

  Future<void> _play() async {
    if (_running) return;
    final token = ++_runToken;
    setState(() => _running = true);

    _setPhase(_LeonidasPhase.standing, _openingLine);
    if (!await _pause(math.max(1200, _openingLine.length * 32), token)) return;

    _setPhase(_LeonidasPhase.summoning, 'Leonidas summons the assigned card.');
    if (!await _pause(900, token)) return;

    var revealed = _wasAlreadyRevealed;
    if (!revealed) {
      try {
        revealed = await widget.onReveal();
      } on Object {
        revealed = false;
      }
    }
    if (!mounted || token != _runToken) return;
    if (!revealed) {
      _setPhase(_LeonidasPhase.revealFailure, _revealFailureLine);
      setState(() => _running = false);
      return;
    }

    _setPhase(_LeonidasPhase.revealing, 'The card reveals.');
    if (!await _pause(1150, token)) return;

    _setPhase(_LeonidasPhase.closeUp, 'The camera moves close.');
    if (!await _pause(650, token)) return;
    if (!await _narrate(_interpretationScript, token)) return;

    if (!mounted || token != _runToken) return;
    setState(() {
      _phase = _LeonidasPhase.complete;
      _caption = _finalCaption;
      _running = false;
    });
  }

  void _cancelRun() {
    _runToken += 1;
    _running = false;
    unawaited(widget.voice.stop());
  }

  void _toggleVoice(bool value) {
    setState(() => _voiceEnabled = value);
    if (!value) unawaited(widget.voice.stop());
  }

  @override
  Widget build(BuildContext context) {
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
                              'TONIGHT’S DAILY RITUAL',
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
                            label: 'Leonidas voice',
                            toggled: _voiceEnabled,
                            onTap: () => _toggleVoice(!_voiceEnabled),
                            child: ExcludeSemantics(
                              child: Switch.adaptive(
                                key: const Key('leonidas-voice-toggle'),
                                value: _voiceEnabled,
                                onChanged: _toggleVoice,
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
                          _CaptionPanel(caption: _caption, speaking: _running),
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
    _LeonidasPhase.idle => 'Awaiting the ritual',
    _LeonidasPhase.standing => 'Leonidas enters',
    _LeonidasPhase.summoning => 'The card is summoned',
    _LeonidasPhase.revealing => 'The card reveals',
    _LeonidasPhase.closeUp => 'Leonidas interprets',
    _LeonidasPhase.complete => 'Reading complete',
    _LeonidasPhase.revealFailure => 'Reveal paused safely',
  };

  Widget _buildActions() {
    final gold = context.ritualColors.gold;
    if (_running) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_phase == _LeonidasPhase.idle ||
        _phase == _LeonidasPhase.revealFailure) {
      return KeyedSubtree(
        key: const Key('ritual-reveal'),
        child: FilledButton.icon(
          key: const Key('leonidas-sequence-start'),
          onPressed: _play,
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            _phase == _LeonidasPhase.revealFailure
                ? 'Try the reveal again'
                : 'Begin with Leonidas',
          ),
        ),
      );
    }
    if (_phase == _LeonidasPhase.complete) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            key: const Key('leonidas-sequence-replay'),
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: const Color(0xFF1A101A),
            ),
            onPressed: _play,
            icon: const Icon(Icons.replay),
            label: const Text('Replay'),
          ),
          if (widget.onShowEvidence != null &&
              widget.ritual.evidence.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('leonidas-evidence'),
              style: OutlinedButton.styleFrom(
                foregroundColor: gold,
                side: BorderSide(color: gold.withValues(alpha: 0.82)),
              ),
              onPressed: widget.onShowEvidence,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Reveal evidence'),
            ),
        ],
      );
    }
    return const SizedBox(height: 48);
  }
}

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
