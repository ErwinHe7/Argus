import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';
import 'package:ritual_investing_app/features/starpath/domain/investment_constellation.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath_universe.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  testWidgets('shows Investment and Trading as two switchable universes', (
    tester,
  ) async {
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Starpath'), findsOneWidget);
    expect(find.byKey(const Key('starpath-universe-selector')), findsOneWidget);
    expect(find.text('Investment'), findsOneWidget);
    expect(find.text('Trading'), findsOneWidget);
    expect(
      find.byKey(const Key('starpath-universe-invest-introduction')),
      findsOneWidget,
    );
    expect(
      find.text('Learn how to build and understand long-term investments.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('starpath-downward-path')), findsOneWidget);
    expect(find.byKey(const Key('starpath-investment-map')), findsOneWidget);
    expect(find.byKey(const Key('starpath-trading-map')), findsNothing);

    await tester.tap(find.text('Trading'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('starpath-universe-trade-introduction')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('starpath-trade-roadmap')), findsOneWidget);
    expect(find.byKey(const Key('starpath-downward-path')), findsNothing);
    expect(find.byKey(const Key('starpath-investment-map')), findsNothing);
    expect(find.byKey(const Key('starpath-trading-map')), findsOneWidget);
    expect(
      find.text('Learn how to read markets and actively trade price movement.'),
      findsOneWidget,
    );
    for (final stop in tradeStarpathUniverse.roadmap) {
      expect(find.text(stop.title), findsOneWidget);
      for (final topic in stop.subtitle.split('·')) {
        expect(find.text(topic.trim()), findsOneWidget);
      }
    }
    expect(tradeStarpathUniverse.roadmap, hasLength(4));
    expect(
      find.text(
        'All four roadmap constellations are visible. Lessons come next.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Investment'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('starpath-downward-path')), findsOneWidget);
    expect(find.byKey(const Key('starpath-trade-roadmap')), findsNothing);
    expect(find.byKey(const Key('starpath-investment-map')), findsOneWidget);
    expect(find.byKey(const Key('starpath-trading-map')), findsNothing);
  });

  testWidgets('shows four open constellations and fourteen short lessons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();
    final snapshot = controller.state.snapshot!;
    final constellations = projectInvestmentConstellations(snapshot);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Your Investment path'), findsOneWidget);
    expect(
      find.text('4 constellations · 14 short lessons · all open'),
      findsOneWidget,
    );
    expect(constellations, hasLength(4));
    expect(
      constellations.map((constellation) => constellation.lessons.length),
      [4, 4, 4, 2],
    );
    for (var ordinal = 1; ordinal <= 4; ordinal += 1) {
      final constellation = find.byKey(
        Key('investment-constellation-$ordinal'),
      );
      expect(constellation, findsOneWidget);
      expect(
        tester.getSemantics(constellation).label,
        contains('$ordinal of 4'),
      );
      expect(tester.getSemantics(constellation).label, contains('available'));
      expect(
        tester
            .getSemantics(constellation)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      for (
        var lesson = 1;
        lesson <= constellations[ordinal - 1].lessons.length;
        lesson += 1
      ) {
        expect(
          find.byKey(Key('investment-map-lesson-$ordinal-$lesson')),
          findsOneWidget,
        );
      }
    }
    expect(
      tester
          .getSemantics(find.byKey(const Key('investment-constellation-4')))
          .label,
      contains('2 short lessons, available'),
    );

    await _openConstellation(tester, 4);
    final lastConstellation = constellations.last;
    expect(find.text(lastConstellation.title), findsOneWidget);
    expect(
      find.text(lastConstellation.lessons.first.section.heading),
      findsOneWidget,
    );
    await _dragUntilBuilt(
      tester,
      find.text(lastConstellation.lessons.last.section.heading),
      const Key('starpath-activity-scroll'),
    );
    semantics.dispose();
  });

  testWidgets('opens any constellation before progress tracking starts', (
    tester,
  ) async {
    final controller = starpathFixtureController(
      currentOrdinal: 1,
      started: false,
    );
    await controller.load();
    final lastConstellation = projectInvestmentConstellations(
      controller.state.snapshot!,
    ).last;
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('starpath-start-progress')), findsOneWidget);
    expect(
      find.textContaining('Open any constellation in any order'),
      findsOneWidget,
    );

    await _openConstellation(tester, 4);
    expect(find.text(lastConstellation.title), findsOneWidget);
    expect(
      find.textContaining('All four constellations are open'),
      findsOneWidget,
    );

    await _openCheck(tester);
    expect(
      find.textContaining('Start progress when you want answers to count'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('starpath-start-from-check')), findsOneWidget);
  });

  testWidgets('groups short lessons inside each Investment constellation', (
    tester,
  ) async {
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();
    final firstConstellation = projectInvestmentConstellations(
      controller.state.snapshot!,
    ).first;
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await _openConstellation(tester, 1);

    expect(find.text('Constellation 1 of 4'), findsOneWidget);
    expect(find.text('Market Basics'), findsOneWidget);
    expect(find.text('The Financial Universe'), findsOneWidget);
    expect(
      find.text(firstConstellation.lessons.first.section.heading),
      findsOneWidget,
    );
    await _dragUntilBuilt(
      tester,
      find.text(firstConstellation.lessons.last.section.heading),
      const Key('starpath-activity-scroll'),
    );
    for (var lesson = 1; lesson <= 4; lesson += 1) {
      expect(
        find.byKey(Key('starpath-constellation-1-lesson-$lesson')),
        findsOneWidget,
      );
    }
  });

  testWidgets('uses continuous human-readable lesson copy with sources', (
    tester,
  ) async {
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();
    final lesson = controller.state.snapshot!.nodes.first.factualSections.first;
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await _openConstellation(tester, 1);
    await _openMicroLesson(tester, constellation: 1, lesson: 1);

    expect(find.text(lesson.heading), findsOneWidget);
    expect(find.text(lesson.body), findsOneWidget);
    expect(find.text('THE IDEA'), findsNothing);
    expect(find.text('PROTECT YOURSELF'), findsNothing);
    expect(find.text('RISK TO REMEMBER'), findsNothing);
    expect(find.text('LIMITS'), findsNothing);
    expect(
      find.textContaining('Keep in mind', findRichText: true),
      findsOneWidget,
    );

    await _dragUntilBuilt(
      tester,
      find.byKey(const Key('starpath-sources')),
      const Key('starpath-micro-lesson-1-1'),
    );
    await tester.tap(find.text('Sources'));
    await tester.pumpAndSettle();
    expect(find.text(lesson.evidence.first.publisher), findsOneWidget);

    final progressBefore =
        controller.state.snapshot?.progress?.currentNodeOrdinal;
    final rowan = find.text('Explain it another way');
    await _dragUntilBuilt(
      tester,
      rowan,
      const Key('starpath-micro-lesson-1-1'),
    );
    await tester.tap(rowan);
    await tester.pumpAndSettle();

    expect(find.text('Rowan’s factual restatement'), findsOneWidget);
    expect(find.textContaining('cannot recommend, predict'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      controller.state.snapshot?.progress?.currentNodeOrdinal,
      progressBefore,
    );
  });

  testWidgets('automatically reads an opened lesson and lets users mute it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final engine = _RecordingNarrationEngine();
    final controller = starpathFixtureController(
      currentOrdinal: 1,
      started: false,
    );
    await controller.load();
    final lesson = controller.state.snapshot!.nodes[7].factualSections.first;
    final progressBefore =
        controller.state.snapshot?.progress?.currentNodeOrdinal;
    await tester.pumpWidget(
      _app(controller, narrationEngineFactory: () => engine),
    );
    await tester.pumpAndSettle();

    await _openConstellation(tester, 4);
    await _openMicroLesson(tester, constellation: 4, lesson: 2);

    expect(engine.spoken, hasLength(1));
    expect(engine.spoken.single, contains(lesson.heading));
    expect(engine.spoken.single, contains('Keep in mind:'));
    expect(find.text('Reading this lesson aloud…'), findsOneWidget);
    expect(find.byTooltip('Mute automatic reading'), findsOneWidget);
    expect(
      find.byKey(const Key('starpath-narration-mute-toggle')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('starpath-narration-mute-toggle')));
    await tester.pump();

    expect(engine.stopCalls, 1);
    expect(find.text('Automatic reading is muted.'), findsOneWidget);
    expect(find.text('Unmute'), findsOneWidget);
    expect(
      controller.state.snapshot?.progress?.currentNodeOrdinal,
      progressBefore,
    );
    semantics.dispose();
  });

  testWidgets('shares mute across lessons and resumes only when unmuted', (
    tester,
  ) async {
    final engine = _RecordingNarrationEngine();
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();
    final firstConstellation = projectInvestmentConstellations(
      controller.state.snapshot!,
    ).first;
    await tester.pumpWidget(
      _app(controller, narrationEngineFactory: () => engine),
    );
    await tester.pumpAndSettle();

    await _openConstellation(tester, 1);
    await _openMicroLesson(tester, constellation: 1, lesson: 1);
    expect(engine.spoken, hasLength(1));

    await tester.tap(find.byKey(const Key('starpath-narration-mute-toggle')));
    await tester.pump();
    expect(engine.stopCalls, 1);

    final next = find.text('Next lesson');
    await _dragUntilBuilt(tester, next, const Key('starpath-micro-lesson-1-1'));
    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('starpath-micro-lesson-1-2')), findsOneWidget);
    expect(find.text('Automatic reading is muted.'), findsOneWidget);
    expect(engine.spoken, hasLength(1));

    await tester.tap(find.byKey(const Key('starpath-narration-mute-toggle')));
    await tester.pumpAndSettle();

    expect(engine.spoken, hasLength(2));
    expect(
      engine.spoken.last,
      contains(firstConstellation.lessons[1].section.heading),
    );
    expect(find.text('Reading this lesson aloud…'), findsOneWidget);
  });

  testWidgets('backgrounding and advancing stop active lesson narration', (
    tester,
  ) async {
    final engine = _RecordingNarrationEngine();
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();
    await tester.pumpWidget(
      _app(controller, narrationEngineFactory: () => engine),
    );
    await tester.pumpAndSettle();

    await _openConstellation(tester, 4);
    await _openMicroLesson(tester, constellation: 4, lesson: 1);
    expect(engine.spoken, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(engine.stopCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byKey(const Key('starpath-read-aloud-play')));
    await tester.pumpAndSettle();
    final next = find.text('Next lesson');
    await _dragUntilBuilt(tester, next, const Key('starpath-micro-lesson-4-1'));
    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(engine.stopCalls, 2);
    expect(engine.spoken, hasLength(3));
    expect(find.byKey(const Key('starpath-micro-lesson-4-2')), findsOneWidget);
  });

  testWidgets('enables the suggested constellation check without lives', (
    tester,
  ) async {
    final controller = starpathFixtureController(
      currentOrdinal: 3,
      answer: const StarpathAnswerFeedback(
        isCorrect: false,
        explanation: 'A positive return is never guaranteed.',
      ),
    );
    await controller.load();
    final wrongLabel =
        controller.state.snapshot!.nodes[2].knowledgeCheck.options[1].label;
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await _openConstellation(tester, 2);
    await _openCheck(tester);

    final wrongOption = find.ancestor(
      of: find.text(wrongLabel),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(wrongOption).onPressed, isNotNull);
    expect(find.textContaining('Not quite yet.'), findsOneWidget);
    expect(find.textContaining('life', findRichText: true), findsNothing);
  });

  testWidgets('future constellations stay readable while checks wait', (
    tester,
  ) async {
    final controller = starpathFixtureController(currentOrdinal: 3);
    await controller.load();
    final lastConstellation = projectInvestmentConstellations(
      controller.state.snapshot!,
    ).last;
    final checkNode = lastConstellation.authoritativeCheckNode;
    final lastLesson = lastConstellation.lessons.last.section;
    final progressBefore =
        controller.state.snapshot?.progress?.currentNodeOrdinal;
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await _openConstellation(tester, 4);
    expect(find.text(lastConstellation.title), findsOneWidget);
    await _openMicroLesson(tester, constellation: 4, lesson: 2);
    expect(find.text(lastLesson.heading), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openCheck(tester);

    final option = find.ancestor(
      of: find.text(checkNode.knowledgeCheck.options.first.label),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(option).onPressed, isNull);
    expect(
      find.textContaining(
        'This check records when this becomes your suggested progress step',
      ),
      findsOneWidget,
    );
    expect(
      controller.state.snapshot?.progress?.currentNodeOrdinal,
      progressBefore,
    );
  });

  testWidgets(
    'draft preview keeps every constellation open and checks read-only',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = starpathFixtureController(
        currentOrdinal: 1,
        draftPreview: true,
      );
      await controller.load();
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('starpath-draft-preview-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('all lessons are open'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const Key('investment-constellation-4')))
            .label,
        allOf(contains('available'), contains('preview')),
      );

      await _openConstellation(tester, 4);
      await _openCheck(tester);
      expect(
        find.textContaining('Preview only. Lessons are open'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets('recall remains optional above the open Investment curriculum', (
    tester,
  ) async {
    final controller = starpathFixtureController(recall: true);
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('starpath-recall')), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.byKey(const Key('investment-constellation-4')), findsOneWidget);
  });

  testWidgets('large text and reduced motion keep both universes accessible', (
    tester,
  ) async {
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
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('investment-constellation-4')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'large-text Investment build',
    );
    expect(find.byKey(const Key('investment-constellation-4')), findsOneWidget);
    expect(
      MediaQuery.of(
        tester.element(find.byKey(const Key('starpath-downward-path'))),
      ).disableAnimations,
      isTrue,
    );

    await tester.ensureVisible(find.text('Trading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trading'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('starpath-trade-roadmap')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'large-text Trading build');
  });

  testWidgets('large text keeps a lesson and Rowan scrollable', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final controller = starpathFixtureController(currentOrdinal: 1);
    await controller.load();
    final lastLesson = projectInvestmentConstellations(
      controller.state.snapshot!,
    ).last.lessons.last.section;

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await _openConstellation(tester, 4);
    await _dragUntilBuilt(
      tester,
      find.text(lastLesson.heading),
      const Key('starpath-activity-scroll'),
    );
    expect(tester.takeException(), isNull, reason: 'large-text Part build');

    await _openMicroLesson(tester, constellation: 4, lesson: 2);
    final rowan = find.text('Explain it another way');
    await _dragUntilBuilt(
      tester,
      rowan,
      const Key('starpath-micro-lesson-4-2'),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'large-text micro-lesson build',
    );

    await tester.tap(rowan);
    await tester.pumpAndSettle();
    expect(find.text('Rowan’s factual restatement'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'large-text Rowan sheet');
  });
}

Future<void> _openConstellation(WidgetTester tester, int displayIndex) async {
  final button = find.byKey(Key('investment-constellation-$displayIndex'));
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byType(StarpathLessonScreen), findsOneWidget);
}

Future<void> _openMicroLesson(
  WidgetTester tester, {
  required int constellation,
  required int lesson,
}) async {
  final row = find.byKey(
    Key('starpath-constellation-$constellation-lesson-$lesson'),
  );
  await _dragUntilBuilt(tester, row, const Key('starpath-activity-scroll'));
  final button = find.descendant(of: row, matching: find.byType(InkWell));
  expect(button, findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(
    find.byKey(Key('starpath-micro-lesson-$constellation-$lesson')),
    findsOneWidget,
  );
}

Future<void> _openCheck(WidgetTester tester) async {
  final check = find.byKey(const Key('starpath-open-check'));
  await _dragUntilBuilt(tester, check, const Key('starpath-activity-scroll'));
  await tester.tap(check);
  await tester.pumpAndSettle();
  expect(find.text('CHECK IT'), findsOneWidget);
}

Future<void> _dragUntilBuilt(
  WidgetTester tester,
  Finder target,
  Key scrollKey,
) async {
  final scroll = find.byKey(scrollKey);
  expect(scroll, findsOneWidget);
  for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scroll, const Offset(0, -260));
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

StarpathNarrationEngine _createRecordingNarrationEngine() =>
    _RecordingNarrationEngine();

Widget _app(
  StarpathController controller, {
  StarpathNarrationEngineFactory narrationEngineFactory =
      _createRecordingNarrationEngine,
}) => MaterialApp(
  theme: AppTheme.light,
  home: StarpathScreen(
    controller: controller,
    narrationEngineFactory: narrationEngineFactory,
  ),
);

class _RecordingNarrationEngine implements StarpathNarrationEngine {
  int stopCalls = 0;
  final List<String> spoken = [];
  VoidCallback? _onStart;
  VoidCallback? _onCancel;

  @override
  void bind({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required VoidCallback onError,
  }) {
    _onStart = onStart;
    _onCancel = onCancel;
  }

  @override
  Future<bool> configure() async => true;

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    _onStart?.call();
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _onCancel?.call();
  }

  @override
  void dispose() {}
}
