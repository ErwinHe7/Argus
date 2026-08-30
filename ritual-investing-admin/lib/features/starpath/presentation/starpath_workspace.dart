import 'package:flutter/material.dart';

import '../../../application/admin_session_controller.dart';
import '../../../data/admin_gateway.dart';
import '../application/starpath_workspace_controller.dart';
import '../domain/starpath_editorial_models.dart';
import 'starpath_lesson_editor.dart';

class StarpathWorkspace extends StatefulWidget {
  const StarpathWorkspace({
    required this.session,
    required this.gateway,
    super.key,
  });

  final AdminSessionController session;
  final AdminGateway gateway;

  @override
  State<StarpathWorkspace> createState() => _StarpathWorkspaceState();
}

class _StarpathWorkspaceState extends State<StarpathWorkspace> {
  late final StarpathWorkspaceController _controller;
  final _reviewReason = TextEditingController(
    text: 'Reviewed against the exact sealed revision and current policy.',
  );
  final _manifestId = TextEditingController();
  final _publicationReason = TextEditingController(
    text: 'Release the reviewed eight-node factual curriculum.',
  );

  @override
  void initState() {
    super.initState();
    _controller = StarpathWorkspaceController(
      session: widget.session,
      gateway: widget.gateway,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _reviewReason.dispose();
    _manifestId.dispose();
    _publicationReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starpath curriculum',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Eight factual investment-literacy lessons. Mythic language is a memory aid only and is never evidence or guidance.',
                ),
                if (_controller.canWrite) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _createLesson,
                    icon: const Icon(Icons.add),
                    label: const Text('New typed lesson'),
                  ),
                ],
                const SizedBox(height: 18),
                if (_controller.loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_controller.error != null)
                  Expanded(child: Center(child: Text(_controller.error!)))
                else
                  Expanded(child: _workspace()),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _workspace() => LayoutBuilder(
    builder: (context, constraints) {
      final list = Card(
        child: ListView.separated(
          itemCount: _controller.records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = _controller.records[index];
            return ListTile(
              selected: _controller.selected?.id == record.id,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(record.title),
              subtitle: Text('${record.status} · revision ${record.version}'),
              onTap: () => _controller.select(record),
            );
          },
        ),
      );
      final detail = _detail();
      if (constraints.maxWidth < 900) {
        return _controller.selected == null ? list : detail;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: list),
          const SizedBox(width: 18),
          Expanded(flex: 5, child: detail),
        ],
      );
    },
  );

  Widget _detail() {
    final lesson = _controller.lesson;
    if (lesson == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a lesson to inspect its member-shaped preview.',
              ),
              const SizedBox(height: 24),
              _manifestStatus(),
            ],
          ),
        ),
      );
    }
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Pathway ${lesson.pathwayOrdinal} · node ${lesson.pathwayPosition} · ${lesson.policyVersion}',
            ),
            const SizedBox(height: 24),
            _section(
              'Mythic mnemonic — memory aid only',
              lesson.mythicMnemonic,
            ),
            _section('Factual lesson', lesson.factualSummary),
            for (final section in lesson.sections) ...[
              _section(section.heading, section.body),
              Text('Uncertainty: ${section.uncertainty}'),
            ],
            _section(
              'Risks and limitations',
              '${lesson.riskContext}\n\n${lesson.materialLimitations}',
            ),
            Text(
              'Dated evidence',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final evidence in lesson.sections.expand(
              (item) => item.evidence,
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_outlined),
                title: Text(evidence.sourceTitle),
                subtitle: Text(
                  '${evidence.publisher} · observed ${_date(evidence.sourceObservedAt)}\n${evidence.canonicalUrl}',
                ),
              ),
            _section(
              'Knowledge check',
              '${lesson.check.prompt}\n${lesson.check.options.map((option) => '• ${option.label}').join('\n')}',
            ),
            _section('Recall', lesson.recallPrompt),
            _section('Explain with Rowan', lesson.rowanExplanation),
            if (lesson.validationIssues.isNotEmpty) ...[
              Text(
                'Validation issues',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final issue in lesson.validationIssues) Text('• $issue'),
              const SizedBox(height: 16),
            ],
            if (_controller.canWrite) ...[
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editLesson(lesson, correction: false),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit draft'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _editLesson(lesson, correction: true),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Create correction revision'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _reviewControls(),
            const Divider(height: 40),
            _manifestStatus(),
          ],
        ),
      ),
    );
  }

  Widget _reviewControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _reviewReason,
        decoration: const InputDecoration(
          labelText: 'Exact-revision review reason',
          helperText: 'Required; retained with discipline, reviewer, hash, policy, and time.',
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_controller.canWrite)
            OutlinedButton(
              onPressed: _controller.submit,
              child: const Text('Submit for dual review'),
            ),
          if (_controller.canReviewFactual)
            FilledButton.tonal(
              onPressed: () => _controller.review(
                StarpathReviewDiscipline.factual,
                StarpathReviewDecision.approved,
                _reviewReason.text,
              ),
              child: const Text('Approve factual'),
            ),
          if (_controller.canReviewCompliance)
            FilledButton.tonal(
              onPressed: () => _controller.review(
                StarpathReviewDiscipline.compliance,
                StarpathReviewDecision.approved,
                _reviewReason.text,
              ),
              child: const Text('Approve compliance'),
            ),
        ],
      ),
    ],
  );

  Widget _manifestStatus() {
    final issues = _controller.manifestPublicationIssues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Atomic manifest', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final issue in issues) Text(issue),
        if (_controller.canPublish) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _manifestId,
            decoration: const InputDecoration(labelText: 'Draft manifest ID'),
          ),
          TextField(
            controller: _publicationReason,
            decoration: const InputDecoration(labelText: 'Publication reason'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: issues.isEmpty
                ? () => _controller.publishManifest(
                    _manifestId.text,
                    _publicationReason.text,
                  )
                : null,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publish eight-node manifest'),
          ),
        ],
      ],
    );
  }

  Widget _section(String heading, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body),
      ],
    ),
  );

  String _date(DateTime? value) => value == null
      ? 'missing date'
      : value.toUtc().toIso8601String().split('T').first;

  Future<void> _createLesson() async {
    final draft = await showDialog<StarpathLessonDraft>(
      context: context,
      builder: (_) => const StarpathLessonEditor(),
    );
    if (draft != null) await _controller.createLesson(draft.stableKey, draft);
  }

  Future<void> _editLesson(
    StarpathLessonDraft lesson, {
    required bool correction,
  }) async {
    final draft = await showDialog<StarpathLessonDraft>(
      context: context,
      builder: (_) => StarpathLessonEditor(initial: lesson),
    );
    if (draft == null) return;
    if (correction) {
      await _controller.createCorrection(draft);
    } else {
      await _controller.saveDraft(draft);
    }
  }
}
