import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Measured geometry and motion for the Daily Ritual's stable stage.
///
/// Viewport values are expressed against a 402×874 iPhone portrait. Stage
/// values are local to the full-width 402×632 surface whose viewport origin is
/// (0, 121).
abstract final class DailyRitualStageSpec {
  static const Size referenceViewport = Size(402, 874);
  static const EdgeInsets pageInsets = EdgeInsets.symmetric(horizontal: 16);
  static const double pageChromeHeight = 62;
  static const Rect headerViewport = Rect.fromLTWH(16, 65, 370, 48);
  static const Rect stageViewport = Rect.fromLTWH(0, 121, 402, 632);

  static const double radius = 16;
  static const Size baseStageSize = Size(402, 632);
  static const Rect metadata = Rect.fromLTWH(12, 10, 378, 44);
  static const Rect voice = Rect.fromLTWH(314, 10, 76, 44);
  static const Rect portrait = Rect.fromLTWH(18, 26, 366, 549);
  static const Rect faceClear = Rect.fromLTWH(132, 68, 138, 178);

  static const double sealBottomInset = 16;
  static const double attunementGuidanceBottom = 205;
  static const Rect restingSealHit = Rect.fromLTWH(121, 456, 160, 160);
  static const Rect holdingSealVisual = Rect.fromLTWH(126, 451, 150, 150);
  static const Rect holdingSealHit = Rect.fromLTWH(111, 436, 180, 180);
  static const Rect restingGuidance = Rect.fromLTWH(20, 485, 362, 48);
  static const Rect restingStart = Rect.fromLTWH(16, 556, 370, 52);

  static const Rect revealedCard = Rect.fromLTWH(142, 248, 118, 206);
  static const Rect revealedContent = Rect.fromLTWH(16, 462, 370, 104);
  static const Rect revealedFinish = Rect.fromLTWH(16, 569, 370, 52);

  static const Rect c2Card = Rect.fromLTWH(115, 255, 172, 300);
  static const Rect c2Caption = Rect.fromLTWH(20, 562, 362, 60);

  static const Rect keepsakeCard = Rect.fromLTWH(20, 272, 118, 206);
  static const Rect keepsakeCopy = Rect.fromLTWH(158, 282, 228, 196);
  static const Rect evidenceAction = Rect.fromLTWH(16, 504, 370, 52);
  static const Rect starpathAction = Rect.fromLTWH(16, 566, 370, 52);

  static const Duration startTransition = Duration(milliseconds: 240);
  static const Duration holdCompression = Duration(milliseconds: 120);
  static const Duration cancelReturn = Duration(milliseconds: 200);
  static const Duration reveal = Duration(milliseconds: 480);
  static const Duration c2Expand = Duration(milliseconds: 450);
  static const Duration c2Settle = Duration(milliseconds: 420);
  static const Duration reducedTransition = Duration(milliseconds: 120);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  static const Key stageKey = Key('leonidas-ritual-sequence');
  static const Key portraitKey = Key('leonidas-portrait-focus');
  static const Key faceClearKey = Key('leonidas-face-clear-zone');
  static const Key sealVisualKey = Key('daily-ritual-seal-visual');
  static const Key sealHitKey = Key('daily-ritual-seal-hit-region');
  static const Key attunementLayerKey = Key('daily-ritual-attunement-layer');
  static const Key attunementFadeKey = Key('daily-ritual-attunement-fade');
  static const Key cardSurfaceKey = Key('daily-ritual-card-surface');
  static const Key cardArtKey = Key('daily-ritual-card-art');
  static const Key readingContentKey = Key('daily-ritual-reading-content');
  static const Key c2CaptionKey = Key('daily-ritual-c2-caption');
  static const Key completedCopyKey = Key('daily-ritual-completed-copy');
  static const Key evidenceKey = Key('leonidas-evidence');
  static const Key starpathKey = Key('leonidas-starpath');

  static double stageHeight(TextScaler scaler) {
    final factor = scaler.scale(16) / 16;
    return baseStageSize.height + math.max(0, factor - 1) * 190;
  }

  static Duration motion(Duration regular, {required bool reducedMotion}) =>
      reducedMotion
      ? (regular == Duration.zero ? Duration.zero : reducedTransition)
      : regular;

  static bool intersectsFaceClear(Rect stageLocalBounds) =>
      faceClear.overlaps(stageLocalBounds);
}
