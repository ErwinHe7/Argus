import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/starpath.dart';

class StarpathPath extends StatelessWidget {
  const StarpathPath({
    super.key,
    required this.nodes,
    required this.onOpenNode,
    required this.readOnly,
  });

  final List<StarpathNode> nodes;
  final ValueChanged<StarpathNode> onOpenNode;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('starpath-downward-path'),
    painter: _ConstellationPathPainter(
      color: context.ritualColors.gold.withValues(alpha: 0.48),
      count: nodes.length,
    ),
    child: Column(
      children: [
        for (final node in nodes)
          _PathNode(
            key: Key('starpath-node-${node.nodeOrdinal}'),
            node: node,
            onPressed: node.state == StarpathNodeState.locked
                ? null
                : () => onOpenNode(node),
            readOnly: readOnly,
          ),
      ],
    ),
  );
}

class _PathNode extends StatelessWidget {
  const _PathNode({
    super.key,
    required this.node,
    required this.onPressed,
    required this.readOnly,
  });

  final StarpathNode node;
  final VoidCallback? onPressed;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritualColors;
    final stateLabel = switch (node.state) {
      StarpathNodeState.completed => 'completed',
      StarpathNodeState.current => 'current',
      StarpathNodeState.locked => 'locked',
    };
    final align = node.nodeOrdinal.isOdd
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final active = node.state == StarpathNodeState.current;
    return Semantics(
      sortKey: OrdinalSortKey(node.nodeOrdinal.toDouble()),
      button: onPressed != null,
      enabled: onPressed != null,
      label:
          'Star ${node.nodeOrdinal} of 8, pathway ${node.pathwayOrdinal}, '
          '${node.title}, $stateLabel${readOnly ? ', read only' : ''}',
      child: ExcludeSemantics(
        child: Align(
          alignment: align,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, minWidth: 232),
              child: Material(
                color: active ? colors.coven : colors.screen,
                elevation: active ? 5 : 0,
                shadowColor: colors.coven.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: active
                        ? colors.gold
                        : node.state == StarpathNodeState.completed
                        ? colors.positive.withValues(alpha: 0.72)
                        : colors.line,
                    width: active ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? colors.gold : colors.screenSoft,
                          ),
                          alignment: Alignment.center,
                          child: Icon(switch (node.state) {
                            StarpathNodeState.completed => Icons.check,
                            StarpathNodeState.current => Icons.auto_awesome,
                            StarpathNodeState.locked => Icons.lock_outline,
                          }, color: active ? colors.coven : colors.muted),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PATHWAY ${node.pathwayOrdinal} · STAR ${node.nodeOrdinal}',
                                style: TextStyle(
                                  color: active ? colors.gold : colors.faint,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                node.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: active ? Colors.white : colors.ink,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                switch (node.state) {
                                  StarpathNodeState.completed =>
                                    'Review the lesson',
                                  StarpathNodeState.current =>
                                    readOnly
                                        ? 'Available offline to read'
                                        : 'Continue learning',
                                  StarpathNodeState.locked =>
                                    'Complete the star above',
                                },
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: active
                                          ? Colors.white70
                                          : colors.muted,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ConstellationPathPainter extends CustomPainter {
  const _ConstellationPathPainter({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    const rowHeight = 138.0;
    for (var index = 0; index < count; index += 1) {
      final point = Offset(
        index.isEven ? size.width * 0.24 : size.width * 0.76,
        index * rowHeight + rowHeight / 2,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.quadraticBezierTo(
          size.width / 2,
          point.dy - rowHeight / 2,
          point.dx,
          point.dy,
        );
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConstellationPathPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.count != count;
}
