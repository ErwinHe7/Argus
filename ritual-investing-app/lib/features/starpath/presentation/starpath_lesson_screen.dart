import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../application/starpath_narration_controller.dart';
import '../domain/investment_constellation.dart';
import '../domain/starpath.dart';
import '../domain/leonidas_story.dart';
import 'leonidas_story_screen.dart';

const _night = Color(0xFF0B0310);
const _aubergine = Color(0xFF15061A);
const _moonInk = Color(0xFFF6ECF7);
const _mutedMoon = Color(0xFFBDA4C2);
const _candleGold = Color(0xFFECB667);
const _softGold = Color(0xFFF7DCAE);
const _learnedGreen = Color(0xFF86BE8A);
const _veilLine = Color(0xFF3F2545);

class StarpathLessonScreen extends StatelessWidget {
  const StarpathLessonScreen({
    super.key,
    required this.controller,
    required this.constellation,
    required this.readOnly,
    required this.narrationPreference,
    this.preview = false,
    this.narrationEngineFactory = createStarpathNarrationEngine,
  });

  final StarpathController controller;
  final InvestmentConstellation constellation;
  final bool readOnly;
  final bool preview;
  final StarpathNarrationPreference narrationPreference;
  final StarpathNarrationEngineFactory narrationEngineFactory;

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentConstellation = _latestConstellation();
        return Scaffold(
          backgroundColor: _night,
          appBar: AppBar(
            backgroundColor: const Color(0xFF100414),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Return to StarPath',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(
              'Constellation ${currentConstellation.displayIndex} of 4',
            ),
            actions: [
              _NarrationPreferenceButton(preference: narrationPreference),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  key: const Key('starpath-activity-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    _ConstellationIntroduction(
                      constellation: currentConstellation,
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel('SHORT LESSONS'),
                    const SizedBox(height: 12),
                    for (
                      var index = 0;
                      index < currentConstellation.lessons.length;
                      index += 1
                    ) ...[
                      _MicroLessonRow(
                        key: Key(
                          'starpath-constellation-${currentConstellation.displayIndex}-lesson-${index + 1}',
                        ),
                        index: index,
                        section: currentConstellation.lessons[index].section,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => _StarpathMicroLessonScreen(
                              controller: controller,
                              constellation: currentConstellation,
                              lessonIndex: index,
                              readOnly: readOnly,
                              preview: preview,
                              narrationPreference: narrationPreference,
                              narrationEngineFactory: narrationEngineFactory,
                            ),
                          ),
                        ),
                      ),
                      if (index != currentConstellation.lessons.length - 1)
                        const Divider(height: 1, color: _veilLine),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('starpath-open-check'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => _StarpathCheckScreen(
                            controller: controller,
                            node: currentConstellation.authoritativeCheckNode,
                            displayConstellationOrdinal:
                                currentConstellation.displayIndex,
                            readOnly: readOnly,
                            preview: preview,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Quick check'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  InvestmentConstellation _latestConstellation() {
    final snapshot = controller.state.snapshot;
    if (snapshot == null) return constellation;
    return projectInvestmentConstellations(
      snapshot,
    )[constellation.displayIndex - 1];
  }
}

class _ConstellationIntroduction extends StatelessWidget {
  const _ConstellationIntroduction({required this.constellation});

  final InvestmentConstellation constellation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Constellation ${constellation.displayIndex}',
        style: const TextStyle(
          color: _candleGold,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        constellation.title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 5),
      Text(
        constellation.leoSubtitle,
        style: const TextStyle(
          color: _softGold,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        constellation.summary,
        style: const TextStyle(color: _mutedMoon, fontSize: 17, height: 1.5),
      ),
      const SizedBox(height: 14),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_open_rounded, color: _candleGold, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'All four constellations are open. Start wherever you need.',
              style: TextStyle(color: _mutedMoon, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    ],
  );
}

class _MicroLessonRow extends StatelessWidget {
  const _MicroLessonRow({
    super.key,
    required this.index,
    required this.section,
    required this.onPressed,
  });

  final int index;
  final StarpathFactualSection section;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Lesson ${index + 1}, ${section.heading}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _candleGold.withValues(alpha: 0.13),
                  border: Border.all(
                    color: _candleGold.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: _softGold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: const TextStyle(
                        color: _moonInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _mutedMoon,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StarpathMicroLessonScreen extends StatefulWidget {
  const _StarpathMicroLessonScreen({
    required this.controller,
    required this.constellation,
    required this.lessonIndex,
    required this.readOnly,
    required this.preview,
    required this.narrationPreference,
    required this.narrationEngineFactory,
    this.notesOnly = false,
  });

  final StarpathController controller;
  final InvestmentConstellation constellation;
  final int lessonIndex;
  final bool readOnly;
  final bool preview;
  final StarpathNarrationPreference narrationPreference;
  final StarpathNarrationEngineFactory narrationEngineFactory;
  final bool notesOnly;

  @override
  State<_StarpathMicroLessonScreen> createState() =>
      _StarpathMicroLessonScreenState();
}

class _StarpathMicroLessonScreenState extends State<_StarpathMicroLessonScreen>
    with WidgetsBindingObserver {
  late final StarpathNarrationController _narration;

  InvestmentLessonEntry get entry =>
      widget.constellation.lessons[widget.lessonIndex];

  StarpathFactualSection get section => entry.section;

  LeonidasStory? get _story {
    if (widget.notesOnly) return null;
    final snapshot = widget.controller.state.snapshot;
    if (snapshot == null) return null;
    final current = snapshot.nodes.where(
      (node) =>
          node.lessonId == entry.node.lessonId &&
          node.revisionId == entry.node.revisionId,
    );
    if (current.isEmpty) return null;
    return resolveLeonidasStory(snapshot, entry);
  }

  void _curriculumChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_curriculumChanged);
    _narration = StarpathNarrationController(
      widget.narrationEngineFactory(),
      script: buildStarpathNarrationScript(
        node: entry.node,
        section: section,
        sectionIndex: entry.sectionIndex,
        displayConstellationOrdinal: widget.constellation.displayIndex,
        displayConstellationTitle: widget.constellation.title,
        displayLessonOrdinal: widget.lessonIndex + 1,
      ),
    );
    widget.narrationPreference.addListener(_syncNarrationPreference);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _story == null &&
          !widget.notesOnly &&
          !widget.narrationPreference.muted) {
        unawaited(_narration.play());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_narration.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_curriculumChanged);
    widget.narrationPreference.removeListener(_syncNarrationPreference);
    _narration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    if (story != null) {
      final isNodeEnd =
          entry.sectionIndex == entry.node.factualSections.length - 1;
      return LeonidasStoryScreen(
        key: ValueKey('${entry.node.revisionId}/${story.id}'),
        playback: widget.controller.storyVisit.open(
          entry.node.revisionId,
          story,
        ),
        narrationPreference: widget.narrationPreference,
        narrationEngineFactory: widget.narrationEngineFactory,
        onNotes: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => _StarpathMicroLessonScreen(
                controller: widget.controller,
                constellation: widget.constellation,
                lessonIndex: widget.lessonIndex,
                readOnly: widget.readOnly,
                preview: widget.preview,
                narrationPreference: widget.narrationPreference,
                narrationEngineFactory: widget.narrationEngineFactory,
                notesOnly: true,
              ),
            ),
          );
        },
        onContinue: _advance,
        continueLabel:
            widget.lessonIndex < widget.constellation.lessons.length - 1
            ? 'Next chapter'
            : 'Back to Market Basics',
        onCheck: isNodeEnd
            ? () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _StarpathCheckScreen(
                      controller: widget.controller,
                      node: entry.node,
                      displayConstellationOrdinal:
                          widget.constellation.displayIndex,
                      readOnly:
                          widget.readOnly || widget.controller.state.isReadOnly,
                      preview: widget.preview,
                    ),
                  ),
                );
              }
            : null,
      );
    }
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: _night,
        appBar: AppBar(
          backgroundColor: const Color(0xFF100414),
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Lesson ${widget.lessonIndex + 1} of ${widget.constellation.lessons.length}',
          ),
          actions: [
            _NarrationPreferenceButton(preference: widget.narrationPreference),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                key: Key(
                  'starpath-micro-lesson-${widget.constellation.displayIndex}-${widget.lessonIndex + 1}',
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Text(
                    'Constellation ${widget.constellation.displayIndex} · ${widget.constellation.title}',
                    style: const TextStyle(
                      color: _candleGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.heading,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: _moonInk),
                  ),
                  const SizedBox(height: 16),
                  _StarpathNarrationControl(
                    key: Key(
                      'starpath-read-aloud-${widget.constellation.displayIndex}-${widget.lessonIndex + 1}',
                    ),
                    controller: _narration,
                    preference: widget.narrationPreference,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    section.body,
                    style: const TextStyle(
                      color: _moonInk,
                      fontSize: 18,
                      height: 1.68,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _KeepInMind(text: section.uncertainty),
                  const SizedBox(height: 22),
                  _Sources(section: section),
                  if (widget.notesOnly) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Limits',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(entry.node.materialLimitations),
                    const SizedBox(height: 16),
                    Text(
                      'Risk context',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(entry.node.riskContext),
                  ],
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _showRowan,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Explain it another way'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _advance,
                    child: Text(
                      widget.notesOnly
                          ? 'Return to story'
                          : widget.lessonIndex <
                                widget.constellation.lessons.length - 1
                          ? 'Next lesson'
                          : 'Back to constellation ${widget.constellation.displayIndex}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _advance() async {
    await _narration.stop();
    if (!mounted) return;
    if (widget.notesOnly) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.lessonIndex < widget.constellation.lessons.length - 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => _StarpathMicroLessonScreen(
            controller: widget.controller,
            constellation: widget.constellation,
            lessonIndex: widget.lessonIndex + 1,
            readOnly: widget.readOnly,
            preview: widget.preview,
            narrationEngineFactory: widget.narrationEngineFactory,
            narrationPreference: widget.narrationPreference,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showRowan() async {
    await _narration.stop();
    if (!mounted) return;
    widget.controller.revealRowan(entry.node.nodeOrdinal);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rowan’s factual restatement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                entry.node.rowanExplanation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              _BoundaryNote(
                text: widget.preview
                    ? 'Draft lesson copy only. Rowan cannot recommend, predict, or change progress here.'
                    : 'Reviewed lesson copy only. Rowan cannot recommend, predict, or change progress here.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close explanation'),
              ),
            ],
          ),
        ),
      ),
    );
    widget.controller.dismissRowan();
  }

  void _syncNarrationPreference() {
    if (_story != null || widget.notesOnly) return;
    if (widget.narrationPreference.muted) {
      unawaited(_narration.stop());
    } else {
      unawaited(_narration.play());
    }
  }
}

class _StarpathNarrationControl extends StatelessWidget {
  const _StarpathNarrationControl({
    super.key,
    required this.controller,
    required this.preference,
  });

  final StarpathNarrationController controller;
  final StarpathNarrationPreference preference;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, preference]),
    builder: (context, _) {
      final phase = controller.phase;
      final status = preference.muted
          ? 'Automatic reading is muted.'
          : switch (phase) {
              StarpathNarrationPhase.idle => 'Ready to read aloud.',
              StarpathNarrationPhase.starting => 'Getting the voice ready…',
              StarpathNarrationPhase.speaking => 'Reading this lesson aloud…',
              StarpathNarrationPhase.completed => 'Finished reading.',
              StarpathNarrationPhase.unavailable => 'Voice is unavailable here. You can still read the lesson below.',
              StarpathNarrationPhase.failure =>
                'Voice stopped. Tap replay to try again.',
            };
      final actionIcon = switch (phase) {
        StarpathNarrationPhase.speaking => Icons.stop_rounded,
        _ => Icons.replay_rounded,
      };
      final isStarting = phase == StarpathNarrationPhase.starting;
      final isSpeaking = phase == StarpathNarrationPhase.speaking;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                preference.muted
                    ? Icons.volume_off_rounded
                    : Icons.graphic_eq_rounded,
                color: _candleGold,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  key: const Key('starpath-read-aloud-status'),
                  liveRegion: phase != StarpathNarrationPhase.idle,
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: _mutedMoon,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              if (!preference.muted)
                IconButton(
                  key: Key(
                    isSpeaking
                        ? 'starpath-read-aloud-stop'
                        : 'starpath-read-aloud-play',
                  ),
                  tooltip: isSpeaking ? 'Stop reading' : 'Read again',
                  onPressed: isStarting
                      ? null
                      : isSpeaking
                      ? controller.stop
                      : controller.play,
                  icon: isStarting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(actionIcon),
                ),
              TextButton(
                key: const Key('starpath-narration-mute-toggle'),
                onPressed: preference.toggle,
                child: Text(preference.muted ? 'Unmute' : 'Mute'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 32),
            child: Text(
              'Uses the English voice on this device or browser.',
              style: TextStyle(color: _mutedMoon, fontSize: 11, height: 1.35),
            ),
          ),
        ],
      );
    },
  );
}

class _NarrationPreferenceButton extends StatelessWidget {
  const _NarrationPreferenceButton({required this.preference});

  final StarpathNarrationPreference preference;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: preference,
    builder: (context, _) => IconButton(
      key: const Key('starpath-global-narration-toggle'),
      tooltip: preference.muted
          ? 'Turn automatic reading on'
          : 'Mute automatic reading',
      onPressed: preference.toggle,
      icon: Icon(
        preference.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      ),
    ),
  );
}

class _KeepInMind extends StatelessWidget {
  const _KeepInMind({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: _candleGold, width: 2)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: _mutedMoon, fontSize: 15, height: 1.55),
          children: [
            const TextSpan(
              text: 'Keep in mind  ',
              style: TextStyle(color: _softGold, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    ),
  );
}

class _StarpathCheckScreen extends StatelessWidget {
  const _StarpathCheckScreen({
    required this.controller,
    required this.node,
    required this.displayConstellationOrdinal,
    required this.readOnly,
    required this.preview,
  });

  final StarpathController controller;
  final StarpathNode node;
  final int displayConstellationOrdinal;
  final bool readOnly;
  final bool preview;

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final snapshot = controller.state.snapshot;
        StarpathNode? latestNode;
        for (final candidate in snapshot?.nodes ?? const <StarpathNode>[]) {
          if (candidate.lessonId == node.lessonId) {
            latestNode = candidate;
            break;
          }
        }
        final canAnswer =
            !readOnly &&
            !preview &&
            snapshot?.session != null &&
            latestNode?.state == StarpathNodeState.current;
        final answer = snapshot?.answer;
        return Scaffold(
          backgroundColor: _night,
          appBar: AppBar(
            backgroundColor: const Color(0xFF100414),
            surfaceTintColor: Colors.transparent,
            title: Text('Constellation $displayConstellationOrdinal check'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    const _SectionLabel('CHECK IT'),
                    const SizedBox(height: 12),
                    Text(
                      node.knowledgeCheck.prompt,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    for (final option in node.knowledgeCheck.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: canAnswer
                              ? () => controller.answer(option.id)
                              : null,
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          child: Text(option.label),
                        ),
                      ),
                    if (answer case final feedback?) ...[
                      const SizedBox(height: 4),
                      Semantics(
                        liveRegion: true,
                        child: _AnswerFeedback(answer: feedback),
                      ),
                      if (feedback.isCorrect) ...[
                        const SizedBox(height: 20),
                        const _Completion(),
                      ],
                    ],
                    if (!canAnswer) ...[
                      const SizedBox(height: 8),
                      _BoundaryNote(
                        text: preview
                            ? 'Preview only. Lessons are open, but checks do not save progress.'
                            : readOnly
                            ? 'Lessons remain open offline. Checks resume when the reviewed curriculum reconnects.'
                            : snapshot?.session == null
                            ? 'Start progress when you want answers to count. You can keep reading any constellation first.'
                            : 'You can read every constellation now. This check records when this becomes your suggested progress step.',
                      ),
                      if (!preview &&
                          !readOnly &&
                          snapshot?.session == null) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('starpath-start-from-check'),
                          onPressed: controller.start,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start tracking progress'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Sources extends StatelessWidget {
  const _Sources({required this.section});

  final StarpathFactualSection section;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: const Key('starpath-sources'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.verified_outlined, color: _mutedMoon, size: 20),
      title: const Text(
        'Sources',
        style: TextStyle(color: _mutedMoon, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Reviewed ${_date(section.observedAt)}',
        style: const TextStyle(color: _mutedMoon),
      ),
      children: [
        for (final evidence in section.evidence) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              evidence.publisher,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              evidence.sourceTitle,
              style: const TextStyle(color: _moonInk, fontSize: 15),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${evidence.canonicalUrl.host} · source observed ${_date(evidence.sourceObservedAt)}',
              style: const TextStyle(color: _mutedMoon, fontSize: 12),
            ),
          ),
          if (evidence != section.evidence.last)
            const Divider(height: 24, color: _veilLine),
        ],
      ],
    ),
  );
}

class _BoundaryNote extends StatelessWidget {
  const _BoundaryNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF3D2600).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _candleGold.withValues(alpha: 0.34)),
    ),
    child: Text(
      text,
      style: const TextStyle(color: _moonInk, fontSize: 15, height: 1.45),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _candleGold,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.answer});

  final StarpathAnswerFeedback answer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: answer.isCorrect
          ? const Color(0xFF4A8150).withValues(alpha: 0.25)
          : const Color(0xFF8A3838).withValues(alpha: 0.23),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: answer.isCorrect ? _learnedGreen : const Color(0xFFD89898),
      ),
    ),
    child: Text(
      '${answer.isCorrect ? 'That matches the reviewed fact.' : 'Not quite yet.'} ${answer.explanation}',
    ),
  );
}

class _Completion extends StatelessWidget {
  const _Completion();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _aubergine,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _learnedGreen.withValues(alpha: 0.65)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _learnedGreen),
            SizedBox(width: 8),
            Text(
              'Check complete',
              style: TextStyle(
                color: _moonInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Your suggested progress marker moves forward. Every constellation stays open.',
          style: TextStyle(color: _mutedMoon, fontSize: 15, height: 1.45),
        ),
      ],
    ),
  );
}

String _date(DateTime value) => value.toIso8601String().substring(0, 10);
