import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  testWidgets('walks downward through eight ordered semantic stars', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = starpathFixtureController();
    await controller.load();

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('starpath-downward-path')), findsOneWidget);
    for (var ordinal = 1; ordinal <= 8; ordinal += 1) {
      expect(find.byKey(Key('starpath-node-$ordinal')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(Key('starpath-node-$ordinal'))).label,
        contains('Star $ordinal of 8'),
      );
    }
    expect(
      tester.getSemantics(find.byKey(const Key('starpath-node-3'))).label,
      contains('current'),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('starpath-node-4'))).label,
      contains('locked'),
    );
    semantics.dispose();
  });

  testWidgets('keeps mythic mnemonic visibly separate from factual lesson', (
    tester,
  ) async {
    final controller = starpathFixtureController();
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await _openCurrentLesson(tester);

    await tester.tap(find.byKey(const Key('starpath-reveal-card')));
    await tester.pump();
    expect(find.text('MYTHIC MEMORY AID'), findsOneWidget);
    expect(find.textContaining('not evidence or a forecast'), findsOneWidget);

    await _dragLessonUntilBuilt(tester, 'FACTUAL LESSON');
    expect(find.text('FACTUAL LESSON'), findsOneWidget);

    await _dragLessonUntilBuilt(tester, 'Investor.gov');
    expect(find.text('Investor.gov'), findsOneWidget);

    await _dragLessonUntilBuilt(tester, 'LIMITATIONS');
    expect(find.text('LIMITATIONS'), findsOneWidget);

    await _dragLessonUntilBuilt(tester, 'RISK CONTEXT');
    expect(find.text('RISK CONTEXT'), findsOneWidget);
    expect(find.text('Buy now'), findsNothing);
    expect(find.text('Trade'), findsNothing);
    expect(find.text('Deposit'), findsNothing);
  });

  testWidgets('recall appears before the current node and remains optional', (
    tester,
  ) async {
    final controller = starpathFixtureController(recall: true);
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('starpath-recall')), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.byKey(const Key('starpath-node-3')), findsOneWidget);
  });

  testWidgets(
    'large text and reduced motion preserve the path without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
          );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final controller = starpathFixtureController();
      await controller.load();

      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'large-text Starpath build',
      );
      expect(find.byKey(const Key('starpath-downward-path')), findsOneWidget);
      expect(
        MediaQuery.of(
          tester.element(find.byKey(const Key('starpath-downward-path'))),
        ).disableAnimations,
        isTrue,
      );
    },
  );

  testWidgets('a wrong answer keeps the check available and never uses lives', (
    tester,
  ) async {
    final controller = starpathFixtureController(
      answer: const StarpathAnswerFeedback(
        isCorrect: false,
        explanation: 'A positive return is never guaranteed.',
      ),
    );
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await _openCurrentLesson(tester);
    await tester.tap(find.byKey(const Key('starpath-reveal-card')));
    await tester.pump();
    await _dragLessonUntilBuilt(
      tester,
      'A share guarantees a positive return.',
    );

    final wrongOption = find.ancestor(
      of: find.text('A share guarantees a positive return.'),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(wrongOption).onPressed, isNotNull);
    expect(find.textContaining('Not quite yet.'), findsOneWidget);
    expect(find.textContaining('life', findRichText: true), findsNothing);
  });

  testWidgets(
    'Rowan only restates reviewed copy without an input or progress',
    (tester) async {
      final controller = starpathFixtureController();
      await controller.load();
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await _openCurrentLesson(tester);
      await tester.tap(find.byKey(const Key('starpath-reveal-card')));
      await tester.pump();
      await _dragLessonUntilBuilt(tester, 'Ask Rowan to restate this fact');
      await tester.tap(find.text('Ask Rowan to restate this fact'));
      await tester.pumpAndSettle();

      expect(find.text('Rowan’s factual restatement'), findsOneWidget);
      expect(find.textContaining('cannot recommend, predict'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(controller.state.rowanNodeOrdinal, 3);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(controller.state.rowanNodeOrdinal, isNull);
    },
  );
}

Future<void> _openCurrentLesson(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
  await tester.pumpAndSettle();
  final node = find.byKey(const Key('starpath-node-3'));
  await tester.tap(find.descendant(of: node, matching: find.byType(InkWell)));
  await tester.pumpAndSettle();
  expect(find.byType(StarpathLessonScreen), findsOneWidget);
}

Future<void> _dragLessonUntilBuilt(WidgetTester tester, String text) async {
  for (
    var attempt = 0;
    attempt < 6 && find.text(text).evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();
  }
  expect(find.text(text), findsOneWidget);
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

Widget _app(StarpathController controller) => MaterialApp(
  theme: AppTheme.light,
  home: StarpathScreen(controller: controller),
);
