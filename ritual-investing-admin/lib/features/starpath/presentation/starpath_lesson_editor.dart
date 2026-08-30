import 'package:flutter/material.dart';

import '../domain/starpath_editorial_models.dart';

class StarpathLessonEditor extends StatefulWidget {
  const StarpathLessonEditor({this.initial, super.key});

  final StarpathLessonDraft? initial;

  @override
  State<StarpathLessonEditor> createState() => _StarpathLessonEditorState();
}

class _StarpathLessonEditorState extends State<StarpathLessonEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  List<String> _issues = const [];

  @override
  void initState() {
    super.initState();
    final value = widget.initial?.toPayload() ?? _emptyPayload();
    final section = (value['sections']! as List).first as Map;
    final evidence = (section['evidence']! as List).first as Map;
    final check = value['check']! as Map;
    final options = check['options']! as List;
    final firstOption = options.first as Map;
    final secondOption = options[1] as Map;
    _fields = {
      'stable_key': _controller(value['stable_key']),
      'pathway_ordinal': _controller(value['pathway_ordinal']),
      'pathway_position': _controller(value['pathway_position']),
      'policy_version': _controller(value['policy_version']),
      'title': _controller(value['title']),
      'tarot_key': _controller(value['tarot_key']),
      'tarot_accessible_label': _controller(value['tarot_accessible_label']),
      'mythic_mnemonic': _controller(value['mythic_mnemonic']),
      'factual_summary': _controller(value['factual_summary']),
      'material_limitations': _controller(value['material_limitations']),
      'risk_context': _controller(value['risk_context']),
      'recall_prompt': _controller(value['recall_prompt']),
      'rowan_explanation': _controller(value['rowan_explanation']),
      'section_heading': _controller(section['heading']),
      'section_body': _controller(section['body']),
      'section_uncertainty': _controller(section['uncertainty']),
      'section_observed_at': _controller(section['observed_at']),
      'canonical_url': _controller(evidence['canonical_url']),
      'source_title': _controller(evidence['source_title']),
      'publisher': _controller(evidence['publisher']),
      'source_observed_at': _controller(evidence['source_observed_at']),
      'retrieved_at': _controller(evidence['retrieved_at']),
      'current_until': _controller(evidence['current_until']),
      'claim_summary': _controller(evidence['claim_summary']),
      'check_prompt': _controller(check['prompt']),
      'check_explanation': _controller(check['explanation']),
      'correct_label': _controller(firstOption['label']),
      'correct_explanation': _controller(firstOption['explanation']),
      'incorrect_label': _controller(secondOption['label']),
      'incorrect_explanation': _controller(secondOption['explanation']),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? 'New Starpath lesson'
              : 'Edit Starpath revision',
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: 'Close editor',
        ),
        actions: [
          FilledButton(
            onPressed: _finish,
            child: const Text('Validate and continue'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          key: const Key('starpath-editor-scroll'),
          padding: const EdgeInsets.all(24),
          children: [
            const _EditorHeading(
              'Lesson identity',
              'Stable pathway placement and the policy version cannot be inferred from prose.',
            ),
            _field('stable_key', 'Stable slug'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'pathway_ordinal',
                    'Pathway (1–4)',
                    integer: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'pathway_position',
                    'Position (1–2)',
                    integer: true,
                  ),
                ),
              ],
            ),
            _field('policy_version', 'No-advice policy version'),
            _field('title', 'Lesson title'),
            const _EditorHeading(
              'Mythic mnemonic',
              'A memory aid only. It must not predict markets or imply suitability.',
            ),
            _field('tarot_key', 'Tarot guide key'),
            _field('tarot_accessible_label', 'Tarot accessible label'),
            _field('mythic_mnemonic', 'Mythic mnemonic', lines: 3),
            const _EditorHeading(
              'Factual lesson',
              'Keep the claim, limitations, risk, recall, and deterministic Rowan explanation separate.',
            ),
            _field('factual_summary', 'Factual summary', lines: 3),
            _field('material_limitations', 'Material limitations', lines: 3),
            _field('risk_context', 'Risk context', lines: 3),
            _field('recall_prompt', 'Recall prompt', lines: 2),
            _field('rowan_explanation', 'Rowan explanation', lines: 3),
            const _EditorHeading(
              'Factual section',
              'One bounded section for this editor pass.',
            ),
            _field('section_heading', 'Section heading'),
            _field('section_body', 'Section body', lines: 5),
            _field('section_uncertainty', 'Uncertainty', lines: 3),
            _field('section_observed_at', 'Section observation timestamp'),
            const _EditorHeading(
              'Dated primary evidence',
              'A secure canonical URL and freshness window are required.',
            ),
            _field('canonical_url', 'Canonical source URL'),
            _field('source_title', 'Source title'),
            _field('publisher', 'Publisher'),
            _field('source_observed_at', 'Source observation timestamp'),
            _field('retrieved_at', 'Retrieved timestamp'),
            _field('current_until', 'Current-until timestamp'),
            _field('claim_summary', 'Supported claim', lines: 3),
            const _EditorHeading(
              'Comprehension check',
              'Exactly one answer is factual. No preference or investment choice questions.',
            ),
            _field('check_prompt', 'Knowledge-check prompt', lines: 2),
            _field(
              'check_explanation',
              'Knowledge-check explanation',
              lines: 3,
            ),
            _field('correct_label', 'Factual answer'),
            _field('correct_explanation', 'Factual answer explanation'),
            _field('incorrect_label', 'Non-factual answer'),
            _field('incorrect_explanation', 'Non-factual answer explanation'),
            if (_issues.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Cannot continue',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final issue in _issues) Text('• $issue'),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      maxLines: lines,
      keyboardType: integer ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Required.' : null,
    ),
  );

  void _finish() {
    if (!_formKey.currentState!.validate()) return;
    final draft = StarpathLessonDraft.fromPayload({
      'stable_key': _text('stable_key'),
      'pathway_ordinal': int.tryParse(_text('pathway_ordinal')) ?? 0,
      'pathway_position': int.tryParse(_text('pathway_position')) ?? 0,
      'policy_version': _text('policy_version'),
      'classification': 'education_general',
      'title': _text('title'),
      'tarot_key': _text('tarot_key'),
      'tarot_accessible_label': _text('tarot_accessible_label'),
      'mythic_mnemonic': _text('mythic_mnemonic'),
      'factual_summary': _text('factual_summary'),
      'material_limitations': _text('material_limitations'),
      'risk_context': _text('risk_context'),
      'recall_prompt': _text('recall_prompt'),
      'rowan_explanation': _text('rowan_explanation'),
      'sections': [
        {
          'kind': 'fact',
          'heading': _text('section_heading'),
          'body': _text('section_body'),
          'uncertainty': _text('section_uncertainty'),
          'observed_at': _text('section_observed_at'),
          'evidence': [
            {
              'canonical_url': _text('canonical_url'),
              'source_title': _text('source_title'),
              'publisher': _text('publisher'),
              'source_observed_at': _text('source_observed_at'),
              'effective_at': null,
              'retrieved_at': _text('retrieved_at'),
              'current_until': _text('current_until'),
              'claim_summary': _text('claim_summary'),
            },
          ],
        },
      ],
      'check': {
        'prompt': _text('check_prompt'),
        'explanation': _text('check_explanation'),
        'options': [
          {
            'label': _text('correct_label'),
            'is_correct': true,
            'explanation': _text('correct_explanation'),
          },
          {
            'label': _text('incorrect_label'),
            'is_correct': false,
            'explanation': _text('incorrect_explanation'),
          },
        ],
      },
    });
    if (draft.validationIssues.isNotEmpty) {
      setState(() => _issues = draft.validationIssues);
      return;
    }
    Navigator.pop(context, draft);
  }

  String _text(String key) => _fields[key]!.text.trim();
  TextEditingController _controller(Object? value) =>
      TextEditingController(text: value?.toString() ?? '');

  Map<String, Object?> _emptyPayload() => {
    'stable_key': '',
    'pathway_ordinal': 1,
    'pathway_position': 1,
    'policy_version': 'starpath-no-advice-v1',
    'classification': 'education_general',
    'title': '',
    'tarot_key': '',
    'tarot_accessible_label': '',
    'mythic_mnemonic': '',
    'factual_summary': '',
    'material_limitations': '',
    'risk_context': '',
    'recall_prompt': '',
    'rowan_explanation': '',
    'sections': [
      {
        'kind': 'fact',
        'heading': '',
        'body': '',
        'uncertainty': '',
        'observed_at': '',
        'evidence': [
          {
            'canonical_url': '',
            'source_title': '',
            'publisher': '',
            'source_observed_at': '',
            'effective_at': null,
            'retrieved_at': '',
            'current_until': '',
            'claim_summary': '',
          },
        ],
      },
    ],
    'check': {
      'prompt': '',
      'explanation': '',
      'options': [
        {'label': '', 'is_correct': true, 'explanation': ''},
        {'label': '', 'is_correct': false, 'explanation': ''},
      ],
    },
  };
}

class _EditorHeading extends StatelessWidget {
  const _EditorHeading(this.title, this.description);
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(description),
      ],
    ),
  );
}
