import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/starpath/application/leonidas_story_playback.dart';
import 'package:ritual_investing_app/features/starpath/domain/leonidas_story.dart';
import 'package:ritual_investing_app/features/starpath/domain/investment_constellation.dart';

import 'support/leonidas_story_fixture.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  for (final story in leonidasStories) {
    test(
      '${story.title}: every branch explains itself and reaches the ending',
      () {
        final player = LeonidasStoryPlayback(story);
        expect(story.beats.length, inInclusiveRange(8, 12));
        expect(
          story.beats.map((beat) => beat.id).toSet().length,
          story.beats.length,
        );
        expect(
          story.beats
              .where((beat) => beat.interaction == StoryInteraction.choice)
              .length,
          2,
        );
        for (var beatIndex = 0; beatIndex < story.beats.length; beatIndex++) {
          expect(player.index, beatIndex);
          final beat = player.beat;
          if (beat.interaction != StoryInteraction.dialogue) {
            expect(player.canAdvance, isFalse);
            player.next();
            expect(player.index, beatIndex);
          }
          if (beat.interaction == StoryInteraction.choice) {
            for (var option = 0; option < beat.options.length; option++) {
              if (beat.options[option].correct) continue;
              player.select(option);
              expect(player.feedback, isNotEmpty);
              expect(player.retry, isTrue);
              expect(player.canAdvance, isFalse);
            }
            expect(
              beat.options.where((option) => option.correct),
              hasLength(1),
            );
            player.select(beat.options.indexWhere((option) => option.correct));
            expect(player.retry, isFalse);
          } else {
            if (beat.interaction == StoryInteraction.sequence) {
              player.select(2);
              expect(player.retry, isTrue);
              expect(player.seen, isEmpty);
            }
            for (var option = 0; option < beat.options.length; option++) {
              player.select(option);
              expect(player.feedback, isNotEmpty);
            }
          }
          expect(player.canAdvance, isTrue);
          player.next();
        }
        expect(player.atEnd, isTrue);
        player.back();
        expect(player.index, story.beats.length - 2);
        player.replay();
        expect(player.index, 0);
        expect(player.feedback, isNull);
        expect(player.seen, isEmpty);
      },
    );
  }

  test('visit resumes only within the same story revision', () {
    final visit = LeonidasStoryVisit();
    final first = visit.open('revision-a', leonidasStories.first)..next();
    expect(visit.open('revision-a', leonidasStories.first), same(first));
    expect(visit.open('revision-a', leonidasStories.first).index, 1);
    expect(visit.open('revision-b', leonidasStories.first).index, 0);
    expect(
      LeonidasStoryVisit().open('revision-a', leonidasStories.first).index,
      0,
    );
  });

  test('resolver rejects unrelated manifests and revisions despite matching titles', () {
    final snapshot = starpathFixtureSnapshot(currentOrdinal: 1);
    final entry = InvestmentLessonEntry(
      node: snapshot.nodes.first,
      sectionIndex: 0,
    );
    expect(resolveLeonidasStory(snapshot, entry), isNull);
    final pilot = pilotSnapshot();
    final lessons = projectInvestmentConstellations(pilot).first.lessons;
    expect(
      lessons.map((entry) => resolveLeonidasStory(pilot, entry)?.id),
      leonidasStories.map((story) => story.id),
    );
    final changed = pilotSnapshot(revision: 'changed');
    expect(
      resolveLeonidasStory(
        changed,
        InvestmentLessonEntry(node: changed.nodes.first, sectionIndex: 0),
      ),
      isNull,
    );
  });
}
