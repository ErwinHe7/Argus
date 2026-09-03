@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  testWidgets(
    'preserves the two universes and four-constellation Investment visuals',
    (tester) async {
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
          home: StarpathScreen(
            controller: controller,
            narrationEngineFactory: _GoldenNarrationEngine.new,
          ),
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

      expect(
        find.byKey(const Key('starpath-universe-selector')),
        findsOneWidget,
      );
      expect(find.text('Investment'), findsOneWidget);
      expect(find.text('Trading'), findsOneWidget);
      for (var ordinal = 1; ordinal <= 4; ordinal += 1) {
        expect(
          find.byKey(Key('investment-constellation-$ordinal')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('investment-constellation-5')), findsNothing);
      expect(find.byKey(const Key('starpath-investment-map')), findsOneWidget);
      expect(find.byKey(const Key('starpath-trading-map')), findsNothing);

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/starpath_path_dark.png'),
      );

      await tester.tap(find.text('Trading'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Starpath'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('starpath-trade-roadmap')), findsOneWidget);
      for (var ordinal = 1; ordinal <= 4; ordinal += 1) {
        expect(
          find.byKey(Key('trading-constellation-$ordinal')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('trading-constellation-5')), findsNothing);
      expect(find.byKey(const Key('starpath-investment-map')), findsNothing);
      expect(find.byKey(const Key('starpath-trading-map')), findsOneWidget);

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/starpath_trading_path_dark.png'),
      );

      await tester.tap(find.text('Investment'));
      await tester.pumpAndSettle();

      final fourthConstellation = find.byKey(
        const Key('investment-constellation-4'),
      );
      await tester.ensureVisible(fourthConstellation);
      await tester.pumpAndSettle();
      await tester.tap(fourthConstellation);
      await tester.pumpAndSettle();
      expect(find.byType(StarpathLessonScreen), findsOneWidget);
      expect(find.text('Constellation 4 of 4'), findsOneWidget);

      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/starpath_part_open_dark.png'),
      );

      final lesson = find.byKey(const Key('starpath-constellation-4-lesson-1'));
      await tester.ensureVisible(lesson);
      final lessonButton = find.descendant(
        of: lesson,
        matching: find.byType(InkWell),
      );
      await tester.tap(lessonButton);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/starpath_micro_lesson_dark.png'),
      );
    },
  );
}

class _GoldenNarrationEngine implements StarpathNarrationEngine {
  VoidCallback? _onStart;

  @override
  void bind({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required VoidCallback onError,
  }) {
    _onStart = onStart;
  }

  @override
  Future<bool> configure() async => true;

  @override
  Future<bool> speak(String text) async {
    _onStart?.call();
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
