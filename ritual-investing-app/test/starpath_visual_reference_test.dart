@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  testWidgets('preserves the approved Starpath and draw activity', (
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

    final controller = starpathFixtureController(currentOrdinal: 2);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StarpathScreen(controller: controller),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      await precacheImage(
        const AssetImage('assets/images/starpath/celestial-path.png'),
        context,
      );
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/starpath_path_dark.png'),
    );

    final node = find.byKey(const Key('starpath-node-2'));
    await tester.ensureVisible(node);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: node, matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(find.byType(StarpathLessonScreen), findsOneWidget);

    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile('goldens/starpath_draw_activity_dark.png'),
    );

    await tester.tap(find.byKey(const Key('starpath-reveal-card')));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).last);
      await precacheImage(
        const AssetImage(
          'assets/images/tarot/modern-rider-waite/major/17-the-star.webp',
        ),
        context,
      );
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold).last,
      matchesGoldenFile('goldens/starpath_memory_activity_dark.png'),
    );
  });
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
