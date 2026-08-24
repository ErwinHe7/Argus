import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritual_investing_app/app/ritual_investing_app.dart';

void main() {
  testWidgets('captures the daily ritual in both approved atmospheres', (
    tester,
  ) async {
    await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
    await _loadFont(
      'LibreBaskerville',
      'assets/fonts/LibreBaskerville-Variable.ttf',
    );
    await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const RitualInvestingApp.fixture());
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/the-compass.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/images/persona-triptych.png'),
          context,
        ),
      ]);
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Warm both theme frames before recording a baseline so the first golden
    // cannot race the initial image decode.
    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();

    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('app-shell-scaffold')),
      matchesGoldenFile('goldens/daily_ritual_light.png'),
    );

    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();

    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('app-shell-scaffold')),
      matchesGoldenFile('goldens/daily_ritual_dark.png'),
    );
  });
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
