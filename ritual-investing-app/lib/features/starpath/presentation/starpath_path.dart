import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../domain/starpath.dart';
import 'starpath_tarot_art.dart';

const _night = Color(0xFF09020D);
const _aubergine = Color(0xFF15061A);
const _plum = Color(0xFF270E2E);
const _moonInk = Color(0xFFFFF7FF);
const _mutedMoon = Color(0xFFCFBED2);
const _faintMoon = Color(0xFF9F8CA3);
const _candleGold = Color(0xFFEDBC70);
const _softGold = Color(0xFFF7DCAE);
const _learnedGreen = Color(0xFF9FD5A5);

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
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final zoneHeight = 430 + ((textScale - 1) * 96);
    return Container(
      key: const Key('starpath-downward-path'),
      decoration: const BoxDecoration(
        color: _night,
        image: DecorationImage(
          image: AssetImage('assets/images/starpath/celestial-path.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          repeat: ImageRepeat.repeatY,
          opacity: 0.7,
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x2215061A), Color(0xB309020D)],
          ),
        ),
        child: Column(
          children: [
            for (var pathway = 1; pathway <= 4; pathway++) ...[
              if (pathway > 1) const _ConstellationDivider(),
              _PathwayZone(
                copy: _pathways[pathway - 1],
                nodes: nodes
                    .where((node) => node.pathwayOrdinal == pathway)
                    .toList(growable: false),
                height: zoneHeight,
                readOnly: readOnly,
                preview: preview,
                onOpenNode: onOpenNode,
                currentNodeKey: currentNodeKey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PathwayZone extends StatelessWidget {
  const _PathwayZone({
    required this.copy,
    required this.nodes,
    required this.height,
    required this.readOnly,
    required this.preview,
    required this.onOpenNode,
    required this.currentNodeKey,
  });

  final _PathwayCopy copy;
  final List<StarpathNode> nodes;
  final double height;
  final bool readOnly;
  final bool preview;
  final ValueChanged<StarpathNode> onOpenNode;
  final GlobalKey? currentNodeKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 380;
      final nodeWidth = compact ? 144.0 : 156.0;
      final firstTop = compact ? 152.0 : 150.0;
      final secondTop = compact ? 292.0 : 286.0;
      final locked =
          !preview &&
          nodes.every((node) => node.state == StarpathNodeState.locked);
      Widget nodeWidget(StarpathNode node) => KeyedSubtree(
        key: Key('starpath-node-${node.nodeOrdinal}'),
        child: _StarNode(
          key: node.state == StarpathNodeState.current ? currentNodeKey : null,
          node: node,
          readOnly: readOnly,
          preview: preview,
          onPressed: !preview && node.state == StarpathNodeState.locked
              ? null
              : () => onOpenNode(node),
        ),
      );
      return SizedBox(
        height: height,
        child: Semantics(
          container: true,
          label: '${copy.title}. ${copy.subtitle}',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 20,
                right: compact ? 36 : 78,
                top: 30,
                child: _PathwayTitle(copy: copy, muted: locked),
              ),
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                height: 300,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _ConstellationTrailPainter(
                      color: locked
                          ? Colors.white.withValues(alpha: 0.16)
                          : _candleGold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              if (nodes case [final first, final second]) ...[
                Positioned(
                  left: compact ? 10 : 22,
                  top: firstTop,
                  width: nodeWidth,
                  child: nodeWidget(first),
                ),
                Positioned(
                  right: compact ? 8 : 18,
                  top: secondTop,
                  width: nodeWidth,
                  child: nodeWidget(second),
                ),
              ] else
                for (final node in nodes)
                  Positioned(
                    left: 22,
                    top: firstTop,
                    width: nodeWidth,
                    child: nodeWidget(node),
                  ),
            ],
          ),
        ),
      );
    },
  );
}

class _PathwayTitle extends StatelessWidget {
  const _PathwayTitle({required this.copy, required this.muted});

  final _PathwayCopy copy;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
    decoration: BoxDecoration(
      color: _aubergine.withValues(alpha: muted ? 0.74 : 0.9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: muted
            ? Colors.white.withValues(alpha: 0.16)
            : _candleGold.withValues(alpha: 0.42),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.title,
          style: const TextStyle(
            color: _moonInk,
            fontFamily: 'LibreBaskerville',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          copy.subtitle,
          style: TextStyle(
            color: muted ? _faintMoon : _mutedMoon,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _StarNode extends StatelessWidget {
  const _StarNode({
    super.key,
    required this.node,
    required this.onPressed,
    required this.readOnly,
    required this.preview,
  });

  final StarpathNode node;
  final VoidCallback? onPressed;
  final bool readOnly;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final stateLabel = preview
        ? 'draft preview'
        : switch (node.state) {
            StarpathNodeState.completed => 'completed',
            StarpathNodeState.current => 'current',
            StarpathNodeState.locked => 'locked',
          };
    final fill = preview
        ? _softGold
        : switch (node.state) {
            StarpathNodeState.completed => _learnedGreen,
            StarpathNodeState.current => _softGold,
            StarpathNodeState.locked => _plum,
          };
    final foreground = !preview && node.state == StarpathNodeState.locked
        ? _faintMoon
        : const Color(0xFF28102B);
    final glow = preview
        ? _candleGold
        : switch (node.state) {
            StarpathNodeState.completed => _learnedGreen,
            StarpathNodeState.current => _candleGold,
            StarpathNodeState.locked => Colors.white,
          };
    return Semantics(
      sortKey: OrdinalSortKey(node.nodeOrdinal.toDouble()),
      button: onPressed != null,
      enabled: onPressed != null,
      label:
          'Star ${node.nodeOrdinal} of 8, pathway ${node.pathwayOrdinal}, '
          '${node.title}, $stateLabel${readOnly ? ', read only' : ''}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glow.withValues(
                  alpha: !preview && node.state == StarpathNodeState.locked
                      ? 0.04
                      : 0.14,
                ),
                boxShadow: preview || node.state == StarpathNodeState.current
                    ? [
                        BoxShadow(
                          color: _candleGold.withValues(alpha: 0.34),
                          blurRadius: 8,
                        ),
                      ]
                    : const [],
              ),
              child: Material(
                color: fill,
                shape: CircleBorder(
                  side: BorderSide(
                    color: !preview && node.state == StarpathNodeState.locked
                        ? Colors.white.withValues(alpha: 0.18)
                        : _softGold.withValues(alpha: 0.7),
                  ),
                ),
                child: InkWell(
                  key: Key('starpath-node-button-${node.nodeOrdinal}'),
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      preview
                          ? Icons.visibility_outlined
                          : switch (node.state) {
                              StarpathNodeState.completed =>
                                Icons.check_rounded,
                              StarpathNodeState.current => Icons.auto_awesome,
                              StarpathNodeState.locked => _sigilIcon(
                                node.nodeOrdinal,
                              ),
                            },
                      color: foreground,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              node.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _moonInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              preview
                  ? 'Open draft lesson'
                  : switch (node.state) {
                      StarpathNodeState.completed => 'Concept demonstrated',
                      StarpathNodeState.current =>
                        readOnly
                            ? 'Available to review offline'
                            : 'Draw ${starpathTarotName(node.guide.tarotKey)}',
                      StarpathNodeState.locked => starpathTarotName(
                        node.guide.tarotKey,
                      ),
                    },
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mutedMoon,
                fontSize: 10,
                height: 1.25,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstellationDivider extends StatelessWidget {
  const _ConstellationDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 72,
    child: Row(
      children: [
        Expanded(child: _FadingRule(reverse: false)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Icon(Icons.auto_awesome, color: _candleGold, size: 19),
        ),
        Expanded(child: _FadingRule(reverse: true)),
      ],
    ),
  );
}

class _FadingRule extends StatelessWidget {
  const _FadingRule({required this.reverse});

  final bool reverse;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
        end: reverse ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [Colors.transparent, Color(0x66EDBC70)],
      ),
    ),
  );
}

class _ConstellationTrailPainter extends CustomPainter {
  const _ConstellationTrailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.22, 92)
      ..cubicTo(
        size.width * 0.72,
        118,
        size.width * 0.78,
        182,
        size.width * 0.66,
        236,
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 3, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 13;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationTrailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PathwayCopy {
  const _PathwayCopy(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

const _pathways = [
  _PathwayCopy('The First Constellation', 'Core terms and how markets work'),
  _PathwayCopy('The Scales of Risk', 'Risk, diversification, and fees'),
  _PathwayCopy(
    'The Library of Evidence',
    'Reading factual investment information',
  ),
  _PathwayCopy('The Lantern Against Deception', 'Scams and misleading claims'),
];

IconData _sigilIcon(int ordinal) => const [
  Icons.auto_awesome,
  Icons.wb_sunny_outlined,
  Icons.balance_outlined,
  Icons.nightlight_outlined,
  Icons.menu_book_outlined,
  Icons.shield_outlined,
  Icons.light_mode_outlined,
  Icons.travel_explore_outlined,
][math.max(0, math.min(7, ordinal - 1))];
