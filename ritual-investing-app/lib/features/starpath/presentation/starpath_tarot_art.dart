import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ritual/presentation/ritual_tarot_art.dart';
import '../domain/starpath.dart';

const _night = Color(0xFF09020D);
const _plum = Color(0xFF27102F);
const _moonInk = Color(0xFFFFF7FF);
const _candleGold = Color(0xFFEDBC70);
const _softGold = Color(0xFFF7DCAE);

class StarpathTarotArt extends StatelessWidget {
  const StarpathTarotArt({super.key, required this.node});

  final StarpathNode node;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 80, 310.0);
    return Semantics(
      image: true,
      label: node.guide.accessibleLabel,
      child: ExcludeSemantics(
        child: Container(
          width: width,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _plum,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _candleGold, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  resolveStarpathTarotArtwork(node.guide.tarotKey).assetPath,
                  key: const Key('starpath-tarot-image'),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const DecoratedBox(
                        decoration: BoxDecoration(color: _plum),
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome,
                            color: _candleGold,
                            size: 82,
                          ),
                        ),
                      ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _night.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _softGold.withValues(alpha: 0.68),
                      ),
                    ),
                    child: Text(
                      '${starpathTarotName(node.guide.tarotKey)} · ${node.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _moonInk,
                        fontFamily: 'LibreBaskerville',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
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

class StarpathTarotDeck extends StatelessWidget {
  const StarpathTarotDeck({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('starpath-tarot-deck'),
    height: 410,
    child: Stack(
      alignment: Alignment.center,
      children: const [
        _DeckCard(angle: -0.105, horizontalOffset: -20, opacity: 0.55),
        _DeckCard(angle: 0.105, horizontalOffset: 18, opacity: 0.78),
        _DeckCard(angle: 0, horizontalOffset: 0, opacity: 1, showStar: true),
      ],
    ),
  );
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.angle,
    required this.horizontalOffset,
    required this.opacity,
    this.showStar = false,
  });

  final double angle;
  final double horizontalOffset;
  final double opacity;
  final bool showStar;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(horizontalOffset, 0),
    child: Transform.rotate(
      angle: angle,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: 220,
          height: 350,
          child: CustomPaint(
            painter: const _CardBackPainter(),
            child: showStar
                ? const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: _candleGold,
                      size: 46,
                    ),
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, Paint()..color = _plum);
    canvas.drawRRect(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _candleGold,
    );

    final center = Offset(size.width / 2, size.height / 2);
    final ornament = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _candleGold.withValues(alpha: 0.52);
    canvas.drawCircle(center, 42, ornament);
    canvas.drawCircle(center, 70, ornament);
    for (var ray = 0; ray < 24; ray += 1) {
      final angle = ray * math.pi * 2 / 24;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * 48,
        center + Offset(math.cos(angle), math.sin(angle)) * 94,
        ornament,
      );
    }
    canvas.drawRRect(
      rect.deflate(12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _softGold.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) => false;
}

final Map<String, RitualTarotArtwork> _starpathTarotArtworkByKey =
    Map.unmodifiable({
      for (final artwork in majorArcanaArtwork) artwork.key: artwork,
    });

RitualTarotArtwork resolveStarpathTarotArtwork(String key) {
  final normalized = key.toLowerCase().replaceAll('-', '_');
  return _starpathTarotArtworkByKey[normalized] ??
      _starpathTarotArtworkByKey['the_star']!;
}

String starpathTarotName(String key) => resolveStarpathTarotArtwork(key).title;
