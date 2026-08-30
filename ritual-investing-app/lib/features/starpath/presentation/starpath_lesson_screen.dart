import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../application/starpath_controller.dart';
import '../domain/starpath.dart';
import 'starpath_tarot_art.dart';

class StarpathLessonScreen extends StatefulWidget {
  const StarpathLessonScreen({
    super.key,
    required this.controller,
    required this.node,
    required this.readOnly,
  });

  final StarpathController controller;
  final StarpathNode node;
  final bool readOnly;

  @override
  State<StarpathLessonScreen> createState() => _StarpathLessonScreenState();
}

class _StarpathLessonScreenState extends State<StarpathLessonScreen> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final answer = state.snapshot?.answer;
      final canAnswer =
          !widget.readOnly && widget.node.state == StarpathNodeState.current;
      return Scaffold(
        appBar: AppBar(title: Text('Star ${widget.node.nodeOrdinal} of 8')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Text(
                widget.node.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pathway ${widget.node.pathwayOrdinal} · factual learning ritual',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (!_revealed)
                FilledButton.icon(
                  key: const Key('starpath-reveal-card'),
                  onPressed: () => setState(() => _revealed = true),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Reveal the memory card'),
                )
              else ...[
                Center(child: StarpathTarotArt(node: widget.node)),
                const SizedBox(height: 24),
                _SectionLabel('MYTHIC MEMORY AID'),
                const SizedBox(height: 8),
                Text(
                  widget.node.mythicMnemonic,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),
                _BoundaryNote(
                  text: 'This tarot and horoscope frame is a mnemonic—not evidence or a forecast.',
                ),
                const SizedBox(height: 30),
                _SectionLabel('FACTUAL LESSON'),
                const SizedBox(height: 8),
                Text(
                  widget.node.factualSummary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 18),
                for (final section in widget.node.factualSections)
                  _FactualSection(section: section),
                const SizedBox(height: 20),
                _FactBoundary(
                  label: 'LIMITATIONS',
                  body: widget.node.materialLimitations,
                ),
                const SizedBox(height: 12),
                _FactBoundary(
                  label: 'RISK CONTEXT',
                  body: widget.node.riskContext,
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _showRowan(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Ask Rowan to restate this fact'),
                ),
                const SizedBox(height: 28),
                _SectionLabel('CHECK THE DEFINITION'),
                const SizedBox(height: 8),
                Text(
                  widget.node.knowledgeCheck.prompt,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final option in widget.node.knowledgeCheck.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: canAnswer
                          ? () => widget.controller.answer(option.id)
                          : null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(option.label),
                      ),
                    ),
                  ),
                if (answer != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: _AnswerFeedback(answer: answer),
                  ),
                ],
                if (!canAnswer) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.readOnly
                        ? 'Checks are disabled while this reviewed lesson is offline.'
                        : 'Review complete. Your progress is unchanged.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to Starpath'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

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
              const _BoundaryNote(
                text: 'Reviewed lesson copy only. Rowan cannot recommend, predict, or change progress here.',
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

class _FactualSection extends StatelessWidget {
  const _FactualSection({required this.section});

  final StarpathFactualSection section;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(section.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text('Observed ${_date(section.observedAt)}'),
          const SizedBox(height: 8),
          Text('Uncertainty: ${section.uncertainty}'),
          const Divider(height: 26),
          for (final evidence in section.evidence) ...[
            Text(
              evidence.publisher,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(evidence.sourceTitle),
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
      color: context.ritualColors.screenSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.ritualColors.line),
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
      color: context.ritualColors.goldSoft.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.ritualColors.gold,
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
          ? context.ritualColors.positive.withValues(alpha: 0.12)
          : context.ritualColors.goldSoft.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      '${answer.isCorrect ? 'That matches the reviewed fact.' : 'Not quite yet.'} ${answer.explanation}',
    ),
  );
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
