import 'package:flutter/material.dart';

import '../domain/starpath_universe.dart';

const _night = Color(0xFF0B0310);
const _moonInk = Color(0xFFF6ECF7);
const _mutedMoon = Color(0xFFBDA4C2);
const _softGold = Color(0xFFF7DCAE);
const _deepViolet = Color(0xFF321036);

const _constellationAccents = <Color>[
  Color(0xFFECB667),
  Color(0xFFD69BD4),
  Color(0xFFA9A7E8),
  Color(0xFFE5A6BD),
];

/// The Trading universe rendered as one continuous, freely explorable star map.
///
/// [onOpenStop] is optional while the curriculum is still a roadmap preview.
/// Supplying it turns each large constellation star into an accessible button.
class TradingStarpathPath extends StatelessWidget {
  const TradingStarpathPath({
    super.key,
    required this.universe,
    this.onOpenStop,
  });

  final StarpathUniverseDefinition universe;
  final ValueChanged<StarpathRoadmapStop>? onOpenStop;

  @override
  Widget build(BuildContext context) {
    assert(
      universe.roadmap.length == 4,
      'TradingStarpathPath is designed for exactly four constellations.',
    );
    return Container(
      key: const Key('starpath-trade-roadmap'),
      decoration: const BoxDecoration(
        color: _night,
        image: DecorationImage(
          image: AssetImage('assets/images/starpath/celestial-path.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          repeat: ImageRepeat.repeatY,
          opacity: 0.44,
        ),
      ),
      child: DecoratedBox(
        key: const Key('starpath-trading-map'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x341E0825), Color(0xE60B0310)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
          child: Column(
            key: const Key('starpath-trading-route'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TradingMapHeader(),
              const SizedBox(height: 26),
              for (var index = 0; index < universe.roadmap.length; index++) ...[
                _TradingConstellation(
                  key: Key('trading-constellation-${index + 1}'),
                  stop: universe.roadmap[index],
                  index: index,
                  total: universe.roadmap.length,
                  onPressed: onOpenStop == null
                      ? null
                      : () => onOpenStop!(universe.roadmap[index]),
                ),
                if (index != universe.roadmap.length - 1)
                  _OrbitBridge(fromLeft: index.isEven),
              ],
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: _softGold, size: 15),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'All four roadmap constellations are visible. Lessons come next.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _softGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradingMapHeader extends StatelessWidget {
  const _TradingMapHeader();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trading constellations',
          style: TextStyle(
            color: _moonInk,
            fontFamily: 'LibreBaskerville',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Four connected skills for reading a market and managing a trade.',
          style: TextStyle(color: _mutedMoon, fontSize: 15, height: 1.45),
        ),
      ],
    ),
  );
}

class _TradingConstellation extends StatelessWidget {
  const _TradingConstellation({
    super.key,
    required this.stop,
    required this.index,
    required this.total,
    required this.onPressed,
  });

  final StarpathRoadmapStop stop;
  final int index;
  final int total;
  final VoidCallback? onPressed;

  bool get _isLeft => index.isEven;

  @override
  Widget build(BuildContext context) {
    final accent = _constellationAccents[index % _constellationAccents.length];
    final topics = stop.subtitle
        .split('·')
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .take(4)
        .toList(growable: false);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          'Constellation ${index + 1} of $total, ${stop.title}. '
          '${topics.join(', ')}. Roadmap topics shown.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConstellationButton(
            stop: stop,
            ordinal: index + 1,
            accent: accent,
            alignLeft: _isLeft,
            onPressed: onPressed,
          ),
          const SizedBox(height: 18),
          _TopicStarTrail(
            topics: topics,
            accent: accent,
            alignLeft: _isLeft,
            constellationIndex: index,
          ),
        ],
      ),
    );
  }
}

class _ConstellationButton extends StatelessWidget {
  const _ConstellationButton({
    required this.stop,
    required this.ordinal,
    required this.accent,
    required this.alignLeft,
    required this.onPressed,
  });

  final StarpathRoadmapStop stop;
  final int ordinal;
  final Color accent;
  final bool alignLeft;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Expanded(
      child: Column(
        crossAxisAlignment: alignLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            'CONSTELLATION ${ordinal.toString().padLeft(2, '0')}',
            textAlign: alignLeft ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.25,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stop.title,
            textAlign: alignLeft ? TextAlign.left : TextAlign.right,
            style: const TextStyle(
              color: _moonInk,
              fontFamily: 'LibreBaskerville',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.16,
            ),
          ),
        ],
      ),
    );
    final star = _HeroStar(ordinal: ordinal, accent: accent);
    return Semantics(
      button: onPressed != null,
      enabled: onPressed != null,
      onTap: onPressed,
      label: onPressed == null ? null : 'Open ${stop.title}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('trading-constellation-button-$ordinal'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                child: Row(
                  children: alignLeft
                      ? [star, const SizedBox(width: 17), text]
                      : [text, const SizedBox(width: 17), star],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStar extends StatelessWidget {
  const _HeroStar({required this.ordinal, required this.accent});

  final int ordinal;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    height: 82,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.34),
                  _deepViolet.withValues(alpha: 0.88),
                ],
                stops: const [0.08, 1],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.27),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Color(0xA6000000),
                  blurRadius: 8,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(_constellationIcon(ordinal), color: accent, size: 35),
          ),
        ),
        Positioned(
          right: -1,
          top: 3,
          child: Icon(Icons.auto_awesome, color: _softGold, size: 17),
        ),
        Positioned(
          left: 8,
          bottom: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(color: accent, blurRadius: 7, spreadRadius: 1),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _TopicStarTrail extends StatelessWidget {
  const _TopicStarTrail({
    required this.topics,
    required this.accent,
    required this.alignLeft,
    required this.constellationIndex,
  });

  final List<String> topics;
  final Color accent;
  final bool alignLeft;
  final int constellationIndex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final compact = constraints.maxWidth < 344 || textScale > 1.3;
      if (compact) {
        return _CompactTopicTrail(
          topics: topics,
          accent: accent,
          alignLeft: alignLeft,
          constellationIndex: constellationIndex,
        );
      }
      return SizedBox(
        height: topics.length > 3 ? 174 : 128,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _TopicTrailPainter(
                    accent: accent,
                    alignLeft: alignLeft,
                    count: topics.length,
                  ),
                ),
              ),
            ),
            for (var topicIndex = 0; topicIndex < topics.length; topicIndex++)
              _PositionedTopicStar(
                topic: topics[topicIndex],
                topicIndex: topicIndex,
                constellationIndex: constellationIndex,
                accent: accent,
                alignLeft: alignLeft,
                topicCount: topics.length,
                availableWidth: constraints.maxWidth,
              ),
          ],
        ),
      );
    },
  );
}

class _PositionedTopicStar extends StatelessWidget {
  const _PositionedTopicStar({
    required this.topic,
    required this.topicIndex,
    required this.constellationIndex,
    required this.accent,
    required this.alignLeft,
    required this.topicCount,
    required this.availableWidth,
  });

  final String topic;
  final int topicIndex;
  final int constellationIndex;
  final Color accent;
  final bool alignLeft;
  final int topicCount;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final positions = topicCount > 3
        ? const <Offset>[
            Offset(0.02, 0),
            Offset(0.51, 0.24),
            Offset(0.12, 0.55),
            Offset(0.58, 0.79),
          ]
        : const <Offset>[
            Offset(0.02, 0),
            Offset(0.51, 0.38),
            Offset(0.14, 0.78),
          ];
    var position = positions[topicIndex];
    if (!alignLeft) {
      position = Offset(1 - position.dx - 0.42, position.dy);
    }
    final availableHeight = topicCount > 3 ? 126.0 : 80.0;
    return Positioned(
      left: position.dx * availableWidth,
      top: position.dy * availableHeight,
      width: availableWidth * 0.42,
      child: _TopicStar(
        key: Key('trading-topic-${constellationIndex + 1}-${topicIndex + 1}'),
        topic: topic,
        accent: accent,
      ),
    );
  }
}

class _CompactTopicTrail extends StatelessWidget {
  const _CompactTopicTrail({
    required this.topics,
    required this.accent,
    required this.alignLeft,
    required this.constellationIndex,
  });

  final List<String> topics;
  final Color accent;
  final bool alignLeft;
  final int constellationIndex;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var topicIndex = 0; topicIndex < topics.length; topicIndex++) ...[
        Align(
          alignment: (topicIndex.isEven == alignLeft)
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.72,
            child: _TopicStar(
              key: Key(
                'trading-topic-${constellationIndex + 1}-${topicIndex + 1}',
              ),
              topic: topics[topicIndex],
              accent: accent,
            ),
          ),
        ),
        if (topicIndex != topics.length - 1)
          Align(
            alignment: topicIndex.isEven
                ? Alignment.center
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Container(
                width: 44,
                height: 1,
                color: accent.withValues(alpha: 0.32),
              ),
            ),
          ),
      ],
    ],
  );
}

class _TopicStar extends StatelessWidget {
  const _TopicStar({super.key, required this.topic, required this.accent});

  final String topic;
  final Color accent;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$topic, Trading roadmap topic',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.62)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.star_rounded, color: accent, size: 15),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              topic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _moonInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OrbitBridge extends StatelessWidget {
  const _OrbitBridge({required this.fromLeft});

  final bool fromLeft;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 92,
      width: double.infinity,
      child: CustomPaint(
        painter: _OrbitBridgePainter(
          fromLeft: fromLeft,
          accent: _constellationAccents[fromLeft ? 0 : 1],
        ),
      ),
    ),
  );
}

class _OrbitBridgePainter extends CustomPainter {
  const _OrbitBridgePainter({required this.fromLeft, required this.accent});

  final bool fromLeft;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final startX = fromLeft ? size.width * 0.18 : size.width * 0.82;
    final endX = fromLeft ? size.width * 0.82 : size.width * 0.18;
    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(
        fromLeft ? size.width * 0.18 : size.width * 0.82,
        size.height * 0.42,
        fromLeft ? size.width * 0.70 : size.width * 0.30,
        size.height * 0.55,
        endX,
        size.height,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    _drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = _softGold.withValues(alpha: 0.56)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5,
      dashLength: 6,
      gapLength: 9,
    );
    final sparkleCenter = Offset(size.width * 0.5, size.height * 0.48);
    canvas.drawCircle(
      sparkleCenter,
      3,
      Paint()..color = _softGold.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      sparkleCenter,
      8,
      Paint()
        ..color = _softGold.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitBridgePainter oldDelegate) =>
      oldDelegate.fromLeft != fromLeft || oldDelegate.accent != accent;
}

class _TopicTrailPainter extends CustomPainter {
  const _TopicTrailPainter({
    required this.accent,
    required this.alignLeft,
    required this.count,
  });

  final Color accent;
  final bool alignLeft;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final startX = alignLeft ? size.width * 0.11 : size.width * 0.89;
    final endX = alignLeft ? size.width * 0.75 : size.width * 0.25;
    final path = Path()
      ..moveTo(startX, 18)
      ..cubicTo(
        alignLeft ? size.width * 0.56 : size.width * 0.44,
        size.height * 0.12,
        alignLeft ? size.width * 0.32 : size.width * 0.68,
        size.height * 0.74,
        endX,
        size.height - 20,
      );
    _drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1,
      dashLength: 4,
      gapLength: 7,
    );
  }

  @override
  bool shouldRepaint(covariant _TopicTrailPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.alignLeft != alignLeft ||
      oldDelegate.count != count;
}

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  required double dashLength,
  required double gapLength,
}) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dashLength).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dashLength + gapLength;
    }
  }
}

IconData _constellationIcon(int ordinal) => const [
  Icons.auto_graph_rounded,
  Icons.show_chart_rounded,
  Icons.track_changes_rounded,
  Icons.language_rounded,
][(ordinal - 1).clamp(0, 3).toInt()];
