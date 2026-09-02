import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';

import 'support/starpath_test_fixture.dart';

void main() {
  test(
    'builds narration only from the reviewed on-screen lesson copy',
    () async {
      final starpath = starpathFixtureController(currentOrdinal: 1);
      await starpath.load();
      final node = starpath.state.snapshot!.nodes.first;
      final section = node.factualSections.first;

      final script = buildStarpathNarrationScript(
        node: node,
        section: section,
        sectionIndex: 0,
      );

      expect(
        script,
        [
          'Constellation 1, ${node.title}.',
          'Lesson 1: ${section.heading}.',
          section.body,
          'Keep in mind: ${section.uncertainty}',
        ].join('\n\n'),
      );
      expect(script, isNot(contains(node.rowanExplanation)));
      expect(script, isNot(contains(section.evidence.first.canonicalUrl.host)));
    },
  );

  test('supports play, completion, replay, and stop', () async {
    final engine = _RecordingNarrationEngine();
    final controller = StarpathNarrationController(
      engine,
      script: 'Reviewed lesson.',
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(engine.configureCalls, 1);
    expect(engine.spoken, isEmpty);
    expect(controller.phase, StarpathNarrationPhase.idle);

    await controller.play();
    expect(engine.spoken, ['Reviewed lesson.']);
    expect(controller.phase, StarpathNarrationPhase.speaking);

    engine.complete();
    expect(controller.phase, StarpathNarrationPhase.completed);

    await controller.play();
    expect(engine.spoken, ['Reviewed lesson.', 'Reviewed lesson.']);
    await controller.stop();
    expect(engine.stopCalls, 1);
    expect(controller.phase, StarpathNarrationPhase.idle);
  });

  test('shared narration preference remembers mute state', () {
    final preference = StarpathNarrationPreference();
    addTearDown(preference.dispose);

    expect(preference.muted, isFalse);
    preference.toggle();
    expect(preference.muted, isTrue);
    preference.setMuted(false);
    expect(preference.muted, isFalse);
  });

  test(
    'keeps an unavailable voice retryable without changing the script',
    () async {
      final engine = _RecordingNarrationEngine(available: false);
      final controller = StarpathNarrationController(
        engine,
        script: 'The written lesson remains available.',
      );
      addTearDown(controller.dispose);

      await controller.play();
      expect(controller.phase, StarpathNarrationPhase.unavailable);
      expect(engine.spoken, isEmpty);

      engine.available = true;
      await controller.play();
      expect(engine.configureCalls, 2);
      expect(engine.spoken, ['The written lesson remains available.']);
      expect(controller.phase, StarpathNarrationPhase.speaking);
    },
  );
}

class _RecordingNarrationEngine implements StarpathNarrationEngine {
  _RecordingNarrationEngine({this.available = true});

  bool available;
  int configureCalls = 0;
  int stopCalls = 0;
  bool disposed = false;
  final List<String> spoken = [];
  VoidCallback? _onStart;
  VoidCallback? _onComplete;
  VoidCallback? _onCancel;

  @override
  void bind({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required VoidCallback onError,
  }) {
    _onStart = onStart;
    _onComplete = onComplete;
    _onCancel = onCancel;
  }

  @override
  Future<bool> configure() async {
    configureCalls += 1;
    return available;
  }

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

  void complete() => _onComplete?.call();

  @override
  void dispose() {
    disposed = true;
  }
}
