import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/investment_constellation.dart';
import 'package:ritual_investing_app/features/starpath/domain/leonidas_story.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';

import 'leonidas_story_presentation_test.dart' show RecordingVoice, tapVisible;
import 'support/leonidas_story_fixture.dart';
import 'support/starpath_test_fixture.dart';

void main() {
  testWidgets(
    'all four lesson routes open stories, retain notes, and never mutate progress',
    (tester) async {
      final service = _CountingService();
      final controller = StarpathController(
        repository: StarpathRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        createKey: () => 'story-test',
      );
      await controller.load();
      final preference = StarpathNarrationPreference()..setMuted(true);
      final constellation = projectInvestmentConstellations(
        controller.state.snapshot!,
      ).first;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StarpathLessonScreen(
            controller: controller,
            constellation: constellation,
            readOnly: true,
            preview: true,
            narrationPreference: preference,
            narrationEngineFactory: () => RecordingVoice(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var lesson = 0; lesson < 4; lesson++) {
        final row = find.byKey(
          Key('starpath-constellation-1-lesson-${lesson + 1}'),
        );
        await tester.scrollUntilVisible(row, 180);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text(leonidasStories[lesson].title), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('story-next')));
        final player = controller.storyVisit.open(
          constellation.lessons[lesson].node.revisionId,
          leonidasStories[lesson],
        );
        expect(player.index, 1);
        await tapVisible(tester, find.text('Lesson notes'));
        expect(
          find.text(constellation.lessons[lesson].section.body),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(player.index, 1);
        // Exercise every story response through the same state used by the UI.
        while (!player.atEnd) {
          final beat = player.beat;
          for (var option = 0; option < beat.options.length; option++) {
            if (beat.interaction != StoryInteraction.choice ||
                beat.options[option].correct) {
              player.select(option);
            }
          }
          player.next();
        }
        // Rebuild from a preference change, without touching authoritative state.
        preference.toggle();
        await tester.pumpAndSettle();
        if (lesson.isOdd) {
          await tapVisible(
            tester,
            find.byKey(const Key('story-knowledge-check')),
          );
          expect(
            find.text(
              'Preview only. Lessons are open, but checks do not save progress.',
            ),
            findsOneWidget,
          );
          expect(service.commands, 0);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(service.commands, 0);
      expect(controller.state.snapshot!.version, 2);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      preference.dispose();
    },
  );
}

class _CountingService extends StarpathFixtureService {
  _CountingService() : super(snapshot: pilotSnapshot());
  int commands = 0;
  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async {
    commands++;
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async {
    commands++;
    return snapshot;
  }
}
