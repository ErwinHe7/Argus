import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../domain/investment_constellation.dart';
import '../domain/starpath.dart';

const _night = Color(0xFF09020D);
const _aubergine = Color(0xFF15061A);
const _plum = Color(0xFF3B1743);
const _moonInk = Color(0xFFFFF7FF);
const _mutedMoon = Color(0xFFCFBED2);
const _candleGold = Color(0xFFEDBC70);
const _softGold = Color(0xFFF7DCAE);
const _learnedGreen = Color(0xFF9FD5A5);
const _veilLine = Color(0xFF604066);

class StarpathPath extends StatelessWidget {
  const StarpathPath({
    super.key,
    required this.nodes,
    required this.onOpenNode,
    required this.readOnly,
    this.preview = false,
    this.currentNodeKey,
  });

  final List<StarpathNode> nodes;
  final ValueChanged<StarpathNode> onOpenNode;
  final bool readOnly;
  final bool preview;
  final GlobalKey? currentNodeKey;

  @override
  Widget build(BuildContext context) {
    final constellations = projectInvestmentConstellationsFromNodes(nodes);
    return Container(
      key: const Key('starpath-downward-path'),
      decoration: const BoxDecoration(
        color: _night,
        image: DecorationImage(
          image: AssetImage('assets/images/starpath/celestial-path.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          repeat: ImageRepeat.repeatY,
          opacity: 0.72,
        ),
      ),
      child: DecoratedBox(
        key: const Key('starpath-investment-map'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x1A210B27), Color(0xC709020D)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 38),
          child: Column(
            key: const Key('starpath-investment-route'),
            children: [
              for (
                var index = 0;
                index < constellations.length;
                index += 1
              ) ...[
                _InvestmentConstellationSection(
                  constellation: constellations[index],
                  totalConstellations: constellations.length,
                  mainOnLeft: index.isEven,
                  readOnly: readOnly,
                  preview: preview,
                  currentNodeKey: currentNodeKey,
                  onOpenNode: onOpenNode,
                ),
                if (index != constellations.length - 1)
                  _ConstellationBridge(
                    completed:
                        constellations[index].state ==
                        InvestmentConstellationState.completed,
                    fromLeft: index.isEven,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InvestmentConstellationSection extends StatelessWidget {
  const _InvestmentConstellationSection({
    required this.constellation,
    required this.totalConstellations,
    required this.mainOnLeft,
    required this.readOnly,
    required this.preview,
    required this.currentNodeKey,
    required this.onOpenNode,
  });

  final InvestmentConstellation constellation;
  final int totalConstellations;
  final bool mainOnLeft;
  final bool readOnly;
  final bool preview;
  final GlobalKey? currentNodeKey;
  final ValueChanged<StarpathNode> onOpenNode;

  Color get _accent => switch (constellation.state) {
    InvestmentConstellationState.completed => _learnedGreen,
    InvestmentConstellationState.current => _candleGold,
    InvestmentConstellationState.open => _mutedMoon,
  };

  @override
  Widget build(BuildContext context) {
    final lessons = constellation.lessons;
    final currentLessonIndex = lessons.indexWhere(
      (lesson) => lesson.node.state == StarpathNodeState.current,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          'Constellation ${constellation.displayIndex} of '
          '$totalConstellations, ${constellation.title}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final mainDiameter = compact ? 82.0 : 92.0;
          final lessonWidth = compact ? 132.0 : 150.0;
          final headerHeight = (compact ? 202.0 : 194.0) * textScale;
          final lessonStep =
              (compact ? 108.0 : 112.0) * (1 + (textScale - 1) * 0.5);
          final height = headerHeight + lessonStep * lessons.length + 12;
          return SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _InvestmentTrailPainter(
                        mainOnLeft: mainOnLeft,
                        lessonCount: lessons.length,
                        headerHeight: headerHeight,
                        lessonStep: lessonStep,
                        lessonWidth: lessonWidth,
                        mainDiameter: mainDiameter,
                        color: _accent,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: headerHeight,
                  child: _ConstellationHeading(
                    constellation: constellation,
                    totalConstellations: totalConstellations,
                    accent: _accent,
                    mainOnLeft: mainOnLeft,
                    markerDiameter: mainDiameter,
                    readOnly: readOnly,
                    preview: preview,
                    onPressed: () =>
                        onOpenNode(constellation.authoritativeCheckNode),
                  ),
                ),
                for (var index = 0; index < lessons.length; index += 1)
                  Positioned(
                    top: headerHeight + index * lessonStep,
                    left: _lessonOnLeft(mainOnLeft, index) ? 10 : null,
                    right: _lessonOnLeft(mainOnLeft, index) ? null : 10,
                    width: lessonWidth,
                    child: _LessonDot(
                      mapKey: Key(
                        'investment-map-lesson-${constellation.displayIndex}-${index + 1}',
                      ),
                      entry: lessons[index],
                      lessonIndex: index,
                      totalLessons: lessons.length,
                      readOnly: readOnly,
                      preview: preview,
                      currentNodeKey: index == currentLessonIndex
                          ? currentNodeKey
                          : null,
                      isFirstForNode:
                          lessons.indexWhere(
                            (candidate) =>
                                candidate.node.lessonId ==
                                lessons[index].node.lessonId,
                          ) ==
                          index,
                      onPressed: () => onOpenNode(lessons[index].node),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConstellationHeading extends StatelessWidget {
  const _ConstellationHeading({
    required this.constellation,
    required this.totalConstellations,
    required this.accent,
    required this.mainOnLeft,
    required this.markerDiameter,
    required this.readOnly,
    required this.preview,
    required this.onPressed,
  });

  final InvestmentConstellation constellation;
  final int totalConstellations;
  final Color accent;
  final bool mainOnLeft;
  final double markerDiameter;
  final bool readOnly;
  final bool preview;
  final VoidCallback onPressed;

  String get _stateLabel => switch (constellation.state) {
    InvestmentConstellationState.completed => 'completed and available',
    InvestmentConstellationState.current => 'suggested next and available',
    InvestmentConstellationState.open => 'available',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    sortKey: OrdinalSortKey(constellation.displayIndex * 100),
    button: true,
    enabled: true,
    onTap: onPressed,
    label:
        'Open constellation ${constellation.displayIndex} of '
        '$totalConstellations, ${constellation.title}. '
        'Leo subtitle: ${constellation.leoSubtitle}. '
        '${constellation.lessons.length} short lessons, $_stateLabel'
        '${preview ? ', preview' : ''}${readOnly ? ', read only' : ''}',
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('investment-constellation-${constellation.displayIndex}'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: mainOnLeft
                  ? [
                      _ConstellationMarker(
                        ordinal: constellation.displayIndex,
                        state: constellation.state,
                        accent: accent,
                        diameter: markerDiameter,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ConstellationCopy(
                          constellation: constellation,
                          accent: accent,
                          textAlign: TextAlign.left,
                          crossAxisAlignment: CrossAxisAlignment.start,
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: _ConstellationCopy(
                          constellation: constellation,
                          accent: accent,
                          textAlign: TextAlign.right,
                          crossAxisAlignment: CrossAxisAlignment.end,
                        ),
                      ),
                      const SizedBox(width: 14),
                      _ConstellationMarker(
                        ordinal: constellation.displayIndex,
                        state: constellation.state,
                        accent: accent,
                        diameter: markerDiameter,
                      ),
                    ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConstellationCopy extends StatelessWidget {
  const _ConstellationCopy({
    required this.constellation,
    required this.accent,
    required this.textAlign,
    required this.crossAxisAlignment,
  });

  final InvestmentConstellation constellation;
  final Color accent;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: crossAxisAlignment,
    children: [
      Text(
        constellation.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: const TextStyle(
          color: _moonInk,
          fontFamily: 'LibreBaskerville',
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.15,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      const Flexible(flex: 5, fit: FlexFit.loose, child: SizedBox(height: 5)),
      Text(
        'Leo · ${constellation.leoSubtitle}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: TextStyle(
          color: accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.3,
          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      const Flexible(flex: 6, fit: FlexFit.loose, child: SizedBox(height: 6)),
      Text(
        constellation.summary,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: const TextStyle(
          color: _mutedMoon,
          fontSize: 13,
          height: 1.35,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      const Flexible(flex: 6, fit: FlexFit.loose, child: SizedBox(height: 6)),
      Text(
        '${constellation.lessons.length} lessons · all open  →',
        textAlign: textAlign,
        style: const TextStyle(
          color: _softGold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.3,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
    ],
  );
}

class _ConstellationMarker extends StatelessWidget {
  const _ConstellationMarker({
    required this.ordinal,
    required this.state,
    required this.accent,
    required this.diameter,
  });

  final int ordinal;
  final InvestmentConstellationState state;
  final Color accent;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final fill = switch (state) {
      InvestmentConstellationState.completed => _learnedGreen,
      InvestmentConstellationState.current => _softGold,
      InvestmentConstellationState.open => _plum,
    };
    final foreground = state == InvestmentConstellationState.open
        ? _softGold
        : _aubergine;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: diameter,
            height: diameter,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.13),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(
                    alpha: state == InvestmentConstellationState.current
                        ? 0.34
                        : 0.16,
                  ),
                  blurRadius: state == InvestmentConstellationState.current
                      ? 10
                      : 6,
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [fill.withValues(alpha: 0.98), fill],
                ),
                border: Border.all(color: _softGold.withValues(alpha: 0.68)),
              ),
              child: Icon(Icons.star_rounded, color: foreground, size: 42),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _aubergine,
                border: Border.all(color: accent.withValues(alpha: 0.85)),
              ),
              child: Icon(
                state == InvestmentConstellationState.completed
                    ? Icons.check_rounded
                    : _constellationIcon(ordinal),
                color: accent,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonDot extends StatelessWidget {
  const _LessonDot({
    required this.mapKey,
    required this.entry,
    required this.lessonIndex,
    required this.totalLessons,
    required this.readOnly,
    required this.preview,
    required this.currentNodeKey,
    required this.isFirstForNode,
    required this.onPressed,
  });

  final Key mapKey;
  final InvestmentLessonEntry entry;
  final int lessonIndex;
  final int totalLessons;
  final bool readOnly;
  final bool preview;
  final GlobalKey? currentNodeKey;
  final bool isFirstForNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final completed = entry.node.state == StarpathNodeState.completed;
    final current = entry.node.state == StarpathNodeState.current;
    final accent = completed
        ? _learnedGreen
        : current
        ? _candleGold
        : _mutedMoon;
    final buttonKey = isFirstForNode
        ? Key('starpath-node-button-${entry.node.nodeOrdinal}')
        : Key(
            'starpath-lesson-button-${entry.node.nodeOrdinal}-${entry.sectionIndex + 1}',
          );
    Widget button = Material(
      key: currentNodeKey,
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 86),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallStarDot(
                  completed: completed,
                  current: current,
                  accent: accent,
                ),
                const SizedBox(height: 7),
                Text(
                  entry.section.heading,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: completed || current ? _moonInk : _mutedMoon,
                    fontSize: 12,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                    height: 1.25,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (isFirstForNode) {
      button = KeyedSubtree(
        key: Key('starpath-node-${entry.node.nodeOrdinal}'),
        child: button,
      );
    }
    return Semantics(
      key: mapKey,
      sortKey: OrdinalSortKey(
        entry.node.pathwayOrdinal * 100 + lessonIndex + 1,
      ),
      button: true,
      enabled: true,
      onTap: onPressed,
      label:
          'Lesson ${lessonIndex + 1} of $totalLessons, '
          '${entry.section.heading}, '
          '${completed
              ? 'completed'
              : current
              ? 'suggested next'
              : 'available'}'
          '${preview ? ', preview' : ''}${readOnly ? ', read only' : ''}',
      child: ExcludeSemantics(child: button),
    );
  }
}

class _SmallStarDot extends StatelessWidget {
  const _SmallStarDot({
    required this.completed,
    required this.current,
    required this.accent,
  });

  final bool completed;
  final bool current;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accent.withValues(alpha: completed || current ? 0.16 : 0.08),
      boxShadow: current
          ? [
              BoxShadow(
                color: _candleGold.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ]
          : const [],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed || current
            ? accent
            : _aubergine.withValues(alpha: 0.94),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Icon(
        completed
            ? Icons.check_rounded
            : current
            ? Icons.auto_awesome_rounded
            : Icons.star_rounded,
        color: completed || current ? _aubergine : accent,
        size: 22,
      ),
    ),
  );
}

class _InvestmentTrailPainter extends CustomPainter {
  const _InvestmentTrailPainter({
    required this.mainOnLeft,
    required this.lessonCount,
    required this.headerHeight,
    required this.lessonStep,
    required this.lessonWidth,
    required this.mainDiameter,
    required this.color,
  });

  final bool mainOnLeft;
  final int lessonCount;
  final double headerHeight;
  final double lessonStep;
  final double lessonWidth;
  final double mainDiameter;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mainX = mainOnLeft ? mainDiameter / 2 : size.width - mainDiameter / 2;
    final lessonInset = 10 + lessonWidth / 2;
    final points = <Offset>[
      Offset(mainX, mainDiameter / 2 + 8),
      for (var index = 0; index < lessonCount; index += 1)
        Offset(
          _lessonOnLeft(mainOnLeft, index)
              ? lessonInset
              : size.width - lessonInset,
          headerHeight + index * lessonStep + 31,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index += 1) {
      final from = points[index - 1];
      final to = points[index];
      final vertical = to.dy - from.dy;
      path.cubicTo(
        from.dx,
        from.dy + vertical * 0.42,
        to.dx,
        to.dy - vertical * 0.42,
        to.dx,
        to.dy,
      );
    }
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path, glowPaint);
    _drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = color.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
      dash: 4,
      gap: 10,
    );

    for (var index = 0; index < points.length - 1; index += 1) {
      final from = points[index];
      final to = points[index + 1];
      final sparkle = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      canvas.drawCircle(
        sparkle,
        2.2,
        Paint()..color = _softGold.withValues(alpha: 0.74),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InvestmentTrailPainter oldDelegate) =>
      oldDelegate.mainOnLeft != mainOnLeft ||
      oldDelegate.lessonCount != lessonCount ||
      oldDelegate.headerHeight != headerHeight ||
      oldDelegate.lessonStep != lessonStep ||
      oldDelegate.lessonWidth != lessonWidth ||
      oldDelegate.mainDiameter != mainDiameter ||
      oldDelegate.color != color;
}

class _ConstellationBridge extends StatelessWidget {
  const _ConstellationBridge({required this.completed, required this.fromLeft});

  final bool completed;
  final bool fromLeft;

  @override
  Widget build(BuildContext context) {
    final color = completed ? _learnedGreen : _veilLine;
    return ExcludeSemantics(
      child: SizedBox(
        height: 92,
        child: CustomPaint(
          painter: _ConstellationBridgePainter(
            color: color,
            fromLeft: fromLeft,
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome,
              color: color.withValues(alpha: 0.92),
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConstellationBridgePainter extends CustomPainter {
  const _ConstellationBridgePainter({
    required this.color,
    required this.fromLeft,
  });

  final Color color;
  final bool fromLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final startX = fromLeft ? size.width * 0.22 : size.width * 0.78;
    final endX = fromLeft ? size.width * 0.78 : size.width * 0.22;
    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(
        startX,
        size.height * 0.38,
        endX,
        size.height * 0.62,
        endX,
        size.height,
      );
    _drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = color.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
      dash: 4,
      gap: 10,
    );
  }

  @override
  bool shouldRepaint(covariant _ConstellationBridgePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fromLeft != fromLeft;
}

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  required double dash,
  required double gap,
}) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dash + gap;
    }
  }
}

bool _lessonOnLeft(bool mainOnLeft, int lessonIndex) =>
    lessonIndex.isEven ? !mainOnLeft : mainOnLeft;

IconData _constellationIcon(int ordinal) => const [
  Icons.public_rounded,
  Icons.all_inclusive_rounded,
  Icons.shield_outlined,
  Icons.explore_outlined,
][(ordinal - 1).clamp(0, 3).toInt()];
