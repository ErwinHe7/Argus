import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/starpath.dart';

class StarpathTarotArt extends StatelessWidget {
  const StarpathTarotArt({super.key, required this.node});

  final StarpathNode node;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: node.guide.accessibleLabel,
    child: ExcludeSemantics(
      child: SizedBox(
        width: 220,
        height: 300,
        child: CustomPaint(
          painter: _StarCardPainter(
            ink: context.ritualColors.ink,
            gold: context.ritualColors.gold,
            night: context.ritualColors.coven,
            glow: context.ritualColors.primarySoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '✦  ${node.nodeOrdinal.toString().padLeft(2, '0')}  ✦',
                  style: TextStyle(
                    color: context.ritualColors.gold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Icon(
                  Icons.auto_awesome,
                  size: 84,
                  color: context.ritualColors.gold,
                ),
                Text(
                  node.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.ritualColors.ink,
                    fontFamily: 'LibreBaskerville',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StarCardPainter extends CustomPainter {
  const _StarCardPainter({
    required this.ink,
    required this.gold,
    required this.night,
    required this.glow,
  });

  final Color ink;
  final Color gold;
  final Color night;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas.drawRRect(card, Paint()..color = night);
    canvas.drawRRect(
      card.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = gold,
    );
    canvas.drawRRect(
      card.deflate(13),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = glow.withValues(alpha: 0.72),
    );

    final center = Offset(size.width / 2, size.height * 0.46);
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = gold.withValues(alpha: 0.62);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 150, height: 70),
      orbit,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.45);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 134, height: 56),
      orbit,
    );
    canvas.restore();
    final star = Paint()..color = ink.withValues(alpha: 0.7);
    for (var index = 0; index < 12; index += 1) {
      final angle = index * math.pi * 2 / 12;
      final radius = index.isEven ? size.width * 0.38 : size.width * 0.29;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        index % 3 == 0 ? 2.2 : 1.2,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarCardPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.gold != gold ||
      oldDelegate.night != night ||
      oldDelegate.glow != glow;
}
