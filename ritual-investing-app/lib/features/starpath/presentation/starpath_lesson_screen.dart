import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../domain/starpath.dart';
import 'starpath_tarot_art.dart';

const _night = Color(0xFF09020D);
const _aubergine = Color(0xFF15061A);
const _moonInk = Color(0xFFFFF7FF);
const _mutedMoon = Color(0xFFCFBED2);
const _candleGold = Color(0xFFEDBC70);
const _softGold = Color(0xFFF7DCAE);
const _lilac = Color(0xFFE5B4DF);
const _factBlue = Color(0xFFB7DDFF);
const _factBackground = Color(0xFF102C40);

enum _LessonStep { draw, memory, fact, check }

class StarpathLessonScreen extends StatefulWidget {
  const StarpathLessonScreen({
    super.key,
    required this.controller,
    required this.node,
    required this.readOnly,
    this.preview = false,
  });

  final StarpathController controller;
  final StarpathNode node;
  final bool readOnly;
  final bool preview;

  @override
  State<StarpathLessonScreen> createState() => _StarpathLessonScreenState();
}

class _StarpathLessonScreenState extends State<StarpathLessonScreen> {
  _LessonStep _step = _LessonStep.draw;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.dark,
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          final answer = state.snapshot?.answer;
          final canAnswer =
              !widget.readOnly &&
              widget.node.state == StarpathNodeState.current;
          return Scaffold(
            backgroundColor: _night,
            appBar: AppBar(
              backgroundColor: const Color(0xFF100414),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Close activity',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
              centerTitle: true,
              title: _ProgressPips(step: _step),
              actions: const [
                Center(
                  child: Text(
                    '3 min',
                    style: TextStyle(color: _mutedMoon, fontSize: 12),
                  ),
                ),
                SizedBox(width: 18),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    key: const Key('starpath-activity-scroll'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                    children: switch (_step) {
                      _LessonStep.draw => _drawStep(),
                      _LessonStep.memory => _memoryStep(),
                      _LessonStep.fact => _factStep(context),
                      _LessonStep.check => _checkStep(
                        context,
                        answer: answer,
                        canAnswer: canAnswer,
                      ),
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  List<Widget> _drawStep() => [
    const ExcludeSemantics(child: StarpathTarotDeck()),
    const SizedBox(height: 2),
    _Eyebrow(
      'STAR ${widget.node.nodeOrdinal} · PATHWAY ${widget.node.pathwayOrdinal}',
    ),
    const SizedBox(height: 8),
    const Text(
      'Draw your guide',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _moonInk,
        fontFamily: 'LibreBaskerville',
        fontSize: 27,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Your card shapes how the concept is remembered—not what anyone should invest in.',
      textAlign: TextAlign.center,
      style: TextStyle(color: _mutedMoon, fontSize: 15, height: 1.5),
    ),
    const SizedBox(height: 20),
    _PrimaryButton(
      key: const Key('starpath-reveal-card'),
      label: 'Draw a card',
      onPressed: _advance,
    ),
  ];

  List<Widget> _memoryStep() => [
    Center(child: StarpathTarotArt(node: widget.node)),
    const SizedBox(height: 22),
    _Lens(
      label: 'MYTHIC MEMORY AID',
      body: widget.node.mythicMnemonic,
      ritual: true,
    ),
    const SizedBox(height: 10),
    const _BoundaryNote(
      text: 'This tarot and horoscope frame is a mnemonic—not evidence or a forecast.',
    ),
    const SizedBox(height: 20),
    _PrimaryButton(
      key: const Key('starpath-reveal-fact'),
      label: 'Reveal the financial fact',
      onPressed: _advance,
    ),
  ];

  List<Widget> _factStep(BuildContext context) => [
    _SectionLabel(widget.preview ? 'DRAFT FINANCIAL LESSON' : 'FACTUAL LESSON'),
    const SizedBox(height: 8),
    Text(widget.node.title, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 14),
    _Lens(
      label: widget.preview
          ? 'DRAFT EDUCATIONAL CONCEPT'
          : 'VERIFIED FINANCIAL FACT',
      body: widget.node.factualSummary,
      ritual: false,
    ),
    const SizedBox(height: 8),
    for (final section in widget.node.factualSections)
      _FactualSection(section: section),
    const SizedBox(height: 6),
    _FactBoundary(label: 'LIMITATIONS', body: widget.node.materialLimitations),
    const SizedBox(height: 12),
    _FactBoundary(label: 'RISK CONTEXT', body: widget.node.riskContext),
    const SizedBox(height: 18),
    OutlinedButton.icon(
      onPressed: () => _showRowan(context),
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text('Ask Rowan to restate this fact'),
    ),
    const SizedBox(height: 24),
    _PrimaryButton(
      key: const Key('starpath-open-check'),
      label: 'Test what you understand',
      onPressed: _advance,
    ),
  ];

  List<Widget> _checkStep(
    BuildContext context, {
    required StarpathAnswerFeedback? answer,
    required bool canAnswer,
  }) => [
    _Eyebrow('${starpathTarotName(widget.node.guide.tarotKey)}’S THRESHOLD'),
    const SizedBox(height: 16),
    Text(
      widget.node.knowledgeCheck.prompt,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const SizedBox(height: 14),
    for (final option in widget.node.knowledgeCheck.options)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton(
          onPressed: canAnswer
              ? () => widget.controller.answer(option.id)
              : null,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(option.label),
        ),
      ),
    if (answer case final feedback?) ...[
      const SizedBox(height: 4),
      Semantics(liveRegion: true, child: _AnswerFeedback(answer: feedback)),
      if (feedback.isCorrect) ...[
        const SizedBox(height: 20),
        _Completion(onReturn: () => Navigator.of(context).pop()),
      ],
    ],
    if (!canAnswer) ...[
      const SizedBox(height: 8),
      Text(
        widget.preview
            ? 'Draft preview only. Checks do not record answers or progress.'
            : widget.readOnly
            ? 'Checks are disabled while this reviewed lesson is offline.'
            : 'Review complete. Your progress is unchanged.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        label: 'Return to Starpath',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  ];

  void _advance() {
    if (_step == _LessonStep.check) return;
    setState(() => _step = _LessonStep.values[_step.index + 1]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _showRowan(BuildContext context) async {
    widget.controller.revealRowan(widget.node.nodeOrdinal);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
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
                widget.node.rowanExplanation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              _BoundaryNote(
                text: widget.preview
                    ? 'Draft lesson copy only. Rowan cannot recommend, predict, or change progress here.'
                    : 'Reviewed lesson copy only. Rowan cannot recommend, predict, or change progress here.',
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
    widget.controller.dismissRowan();
  }
}

class _ProgressPips extends StatelessWidget {
  const _ProgressPips({required this.step});

  final _LessonStep step;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${step.index + 1} of ${_LessonStep.values.length}',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < _LessonStep.values.length; index += 1)
            Container(
              width: 28,
              height: 4,
              margin: EdgeInsets.only(
                right: index == _LessonStep.values.length - 1 ? 0 : 5,
              ),
              decoration: BoxDecoration(
                color: index <= step.index
                    ? _candleGold
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      backgroundColor: _softGold,
      foregroundColor: const Color(0xFF251126),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
      ),
    ),
    child: Text(label),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: _candleGold,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

class _Lens extends StatelessWidget {
  const _Lens({required this.label, required this.body, required this.ritual});

  final String label;
  final String body;
  final bool ritual;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: ritual
          ? const Color(0xFF622260).withValues(alpha: 0.28)
          : _factBackground,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: (ritual ? _lilac : _factBlue).withValues(alpha: 0.5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ritual ? _lilac : _factBlue,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          style: const TextStyle(color: _moonInk, fontSize: 14, height: 1.52),
        ),
      ],
    ),
  );
}

class _FactualSection extends StatelessWidget {
  const _FactualSection({required this.section});

  final StarpathFactualSection section;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _factBackground,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _factBlue.withValues(alpha: 0.42)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(section.body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Text(
          'Observed ${_date(section.observedAt)} · uncertainty: ${section.uncertainty}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 26),
        for (final evidence in section.evidence) ...[
          Text(
            evidence.publisher,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(evidence.sourceTitle),
          const SizedBox(height: 3),
          Text(
            'Source observed ${_date(evidence.sourceObservedAt)} · reviewed ${_date(evidence.retrievedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            evidence.canonicalUrl.host,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(decoration: TextDecoration.underline),
          ),
        ],
      ],
    ),
  );
}

class _FactBoundary extends StatelessWidget {
  const _FactBoundary({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _aubergine,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionLabel(label), const SizedBox(height: 6), Text(body)],
    ),
  );
}

class _BoundaryNote extends StatelessWidget {
  const _BoundaryNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF3D2600).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _candleGold.withValues(alpha: 0.34)),
    ),
    child: Text(
      text,
      style: const TextStyle(color: _moonInk, fontSize: 14, height: 1.42),
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
      letterSpacing: 1.25,
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
        color: answer.isCorrect
            ? const Color(0xFF9FD5A5)
            : const Color(0xFFD89898),
      ),
    ),
    child: Text(
      '${answer.isCorrect ? 'That matches the reviewed fact.' : 'Not quite yet.'} ${answer.explanation}',
    ),
  );
}

class _Completion extends StatelessWidget {
  const _Completion({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
    decoration: BoxDecoration(
      color: _aubergine,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(60),
        bottom: Radius.circular(14),
      ),
      border: Border.all(color: _candleGold.withValues(alpha: 0.5)),
    ),
    child: Column(
      children: [
        const Icon(Icons.auto_awesome, color: _candleGold, size: 48),
        Text('Place the star.', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'You separated financial fact from ritual interpretation. The next node can now open.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedMoon, height: 1.45),
        ),
        const SizedBox(height: 8),
        const Text(
          'Learning progress only · no investment action required',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9FD5A5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(label: 'Return to your path', onPressed: onReturn),
      ],
    ),
  );
}

String _date(DateTime value) => value.toIso8601String().substring(0, 10);
