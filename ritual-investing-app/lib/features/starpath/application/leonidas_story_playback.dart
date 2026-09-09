import '../domain/leonidas_story.dart';

/// Local navigation only. No repository, command, score, or learning completion.
class LeonidasStoryVisit {
  final _chapters = <String, LeonidasStoryPlayback>{};
  LeonidasStoryPlayback open(String revisionId, LeonidasStory story) =>
      _chapters.putIfAbsent(
        '$revisionId/${story.id}',
        () => LeonidasStoryPlayback(story),
      );
}

class LeonidasStoryPlayback {
  LeonidasStoryPlayback(this.story);
  final LeonidasStory story;
  int index = 0;
  final _seen = <int, Set<int>>{};
  final _answers = <int, int>{};
  String? feedback;
  bool retry = false;
  StoryBeat get beat => story.beats[index];
  bool get atEnd => index == story.beats.length - 1;
  Set<int> get seen => Set.unmodifiable(_seen[index] ?? <int>{});
  int? get selectedAnswer => _answers[index];
  bool get canAdvance => switch (beat.interaction) {
    StoryInteraction.dialogue => true,
    StoryInteraction.choice => _answers.containsKey(index),
    StoryInteraction.inspect ||
    StoryInteraction.sequence => seen.length == beat.options.length,
  };

  void select(int option) {
    if (option < 0 || option >= beat.options.length) return;
    final value = beat.options[option];
    retry = false;
    if (beat.interaction == StoryInteraction.sequence &&
        !seen.contains(option) &&
        option != seen.length) {
      feedback =
          'Follow the route one stop at a time. Next: ${beat.options[seen.length].label}.';
      retry = true;
      return;
    }
    feedback = value.response;
    if (beat.interaction == StoryInteraction.choice) {
      if (value.correct) {
        _answers[index] = option;
      } else {
        _answers.remove(index);
        retry = true;
      }
    } else {
      (_seen[index] ??= <int>{}).add(option);
    }
  }

  void next() {
    if (!canAdvance || atEnd) return;
    index++;
    feedback = null;
    retry = false;
  }

  void back() {
    if (index == 0) return;
    index--;
    feedback = null;
    retry = false;
  }

  void replay() {
    index = 0;
    _seen.clear();
    _answers.clear();
    feedback = null;
    retry = false;
  }
}
