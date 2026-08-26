import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../application/intention_controller.dart';
import '../domain/model.dart';

class IntentionsScreen extends StatefulWidget {
  const IntentionsScreen({
    super.key,
    required this.portfolioId,
    required this.controller,
    required this.onOpenIntention,
  });

  final String portfolioId;
  final IntentionController controller;
  final ValueChanged<String> onOpenIntention;

  @override
  State<IntentionsScreen> createState() => _IntentionsScreenState();
}

class _IntentionsScreenState extends State<IntentionsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _date;
  bool _showCreate = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _target = TextEditingController(text: '5,000.00');
    _date = TextEditingController();
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    await widget.controller.openPortfolio(widget.portfolioId);
    if (!mounted) return;
    _seedDefaults();
    setState(() {});
  }

  void _seedDefaults() {
    if (_seeded) return;
    final draft = widget.controller.newDraft(targetMinor: 500000);
    _title.text = draft.title;
    _target.text = (draft.targetMinor / 100).toStringAsFixed(2);
    _date.text = _dateOnly(draft.targetDate);
    _seeded = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      _seedDefaults();
      final controller = widget.controller;
      final review = controller.phase == IntentionPhase.createReview;
      final recovery =
          controller.phase == IntentionPhase.restoredReview ||
          controller.phase == IntentionPhase.retryableFailure ||
          controller.phase == IntentionPhase.throttled;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Intentions'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: DemoBadge(horizontalPadding: 9)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const _IntentionsDisclosure(),
              if (controller.isStale) ...[
                const SizedBox(height: 12),
                const _Notice(
                  text: 'Progress is cached. Refresh before relying on it.',
                ),
              ],
              if (controller.message case final message?) ...[
                const SizedBox(height: 12),
                _Notice(text: message),
              ],
              if (controller.phase == IntentionPhase.loading ||
                  controller.phase == IntentionPhase.confirming)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (controller.phase == IntentionPhase.reconciliationRequired)
                _ActionButton(
                  key: const Key('intention-retry-reconciliation'),
                  label: 'Refresh authority',
                  onPressed: () => unawaited(controller.retryReconciliation()),
                ),
              if (recovery) ...[
                _ActionButton(
                  key: const Key('intention-review-recovery'),
                  label: 'Review saved goal',
                  onPressed: controller.reviewRestoredCreate,
                ),
                TextButton(
                  key: const Key('intention-discard-recovery'),
                  onPressed: () => unawaited(controller.discardPendingCreate()),
                  child: const Text('Discard saved recovery'),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Demo goals',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('intentions-new'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => setState(() => _showCreate = true),
                    icon: const Icon(Icons.add),
                    label: const Text('New'),
                  ),
                ],
              ),
              if (controller.intentions.isEmpty &&
                  controller.phase != IntentionPhase.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No goals for this portfolio yet. Create one to track provider-free Demo progress.',
                  ),
                ),
              for (final intention in controller.intentions)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    title: Text(intention.title),
                    subtitle: Text(
                      '${_statusLabel(intention.status)} · '
                      '${MinorMoney.usd(intention.progressMinor)} of '
                      '${MinorMoney.usd(intention.targetMinor)} USD',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenIntention(intention.id),
                  ),
                ),
              if (controller.hasMore)
                OutlinedButton(
                  key: const Key('intentions-load-more'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => unawaited(controller.loadMore()),
                  child: const Text('Load more goals'),
                ),
              if (_showCreate || review) ...[
                const SizedBox(height: 24),
                _CreateIntentionForm(
                  title: _title,
                  target: _target,
                  date: _date,
                  sourceLabel: controller.defaults.sourceLabel,
                  review: review,
                  draft: controller.createDraft,
                  onReview: _reviewCreate,
                  onConfirm: () => unawaited(controller.confirmCreate()),
                  onCancel: () => setState(() => _showCreate = false),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Future<void> _reviewCreate() async {
    final minor = _usdMinor(_target.text);
    final date = _parseDate(_date.text);
    if (minor == null || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid USD target and UTC date.')),
      );
      return;
    }
    await widget.controller.prepareCreate(
      IntentionDraft(
        portfolioId: widget.portfolioId,
        title: _title.text,
        targetMinor: minor,
        targetDate: date,
      ),
    );
  }
}

class IntentionDetailScreen extends StatefulWidget {
  const IntentionDetailScreen({
    super.key,
    required this.portfolioId,
    required this.intentionId,
    required this.controller,
    required this.onOpenFutureMirror,
  });

  final String portfolioId;
  final String intentionId;
  final IntentionController controller;
  final VoidCallback onOpenFutureMirror;

  @override
  State<IntentionDetailScreen> createState() => _IntentionDetailScreenState();
}

class _IntentionDetailScreenState extends State<IntentionDetailScreen> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _date;
  bool _editing = false;
  String? _seededId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _target = TextEditingController();
    _date = TextEditingController();
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    await widget.controller.openPortfolio(widget.portfolioId);
    await widget.controller.openIntention(widget.intentionId);
  }

  void _seed(Intention value) {
    if (_seededId == value.id) return;
    _title.text = value.title;
    _target.text = (value.targetMinor / 100).toStringAsFixed(2);
    _date.text = _dateOnly(value.targetDate);
    _seededId = value.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final value = controller.selected;
      if (value != null) _seed(value);
      return Scaffold(
        appBar: AppBar(title: const Text('Intention')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const _IntentionsDisclosure(),
              if (controller.message case final message?) ...[
                const SizedBox(height: 12),
                _Notice(text: message),
              ],
              if (value == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                const SizedBox(height: 20),
                Text(
                  value.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${MinorMoney.usd(value.progressMinor)} of '
                  '${MinorMoney.usd(value.targetMinor)} USD · '
                  '${value.progressBps / 100}% · ${_statusLabel(value.status)}',
                ),
                Text(
                  'Target date ${_dateOnly(value.targetDate)} · version ${value.version}',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('intention-open-future-mirror'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: value.status == IntentionStatus.archived
                      ? null
                      : widget.onOpenFutureMirror,
                  icon: const Icon(Icons.auto_graph_outlined),
                  label: const Text('Open Future Mirror'),
                ),
                OutlinedButton(
                  key: const Key('intention-edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: value.status == IntentionStatus.archived
                      ? null
                      : () => setState(() => _editing = true),
                  child: const Text('Edit goal'),
                ),
                if (_editing || controller.phase == IntentionPhase.editReview)
                  _EditIntentionForm(
                    title: _title,
                    target: _target,
                    date: _date,
                    review: controller.phase == IntentionPhase.editReview,
                    onReview: () => _reviewEdit(value),
                    onConfirm: () => unawaited(controller.confirmEdit()),
                  ),
                const Divider(height: 36),
                if (controller.phase == IntentionPhase.archiveReview)
                  FilledButton(
                    key: const Key('intention-confirm-archive'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => unawaited(controller.confirmArchive()),
                    child: const Text('Confirm archive'),
                  )
                else
                  TextButton(
                    key: const Key('intention-archive'),
                    onPressed: value.status == IntentionStatus.archived
                        ? null
                        : controller.prepareArchive,
                    child: const Text('Archive this goal'),
                  ),
                if (controller.phase == IntentionPhase.conflictReview &&
                    controller.editDraft != null)
                  _ActionButton(
                    key: const Key('intention-review-edit-conflict'),
                    label: 'Review edit against latest version',
                    onPressed: controller.reviewEditAgainstAuthority,
                  ),
                if (controller.phase == IntentionPhase.conflictReview &&
                    controller.archivePending)
                  _ActionButton(
                    key: const Key('intention-review-archive-conflict'),
                    label: 'Review archive against latest version',
                    onPressed: controller.reviewArchiveAgainstAuthority,
                  ),
                if (controller.phase == IntentionPhase.reconciliationRequired)
                  _ActionButton(
                    key: const Key('intention-detail-retry-authority'),
                    label: 'Refresh goal authority',
                    onPressed: () =>
                        unawaited(controller.retryReconciliation()),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );

  void _reviewEdit(Intention current) {
    final minor = _usdMinor(_target.text);
    final date = _parseDate(_date.text);
    if (minor == null || date == null) return;
    widget.controller.prepareEdit(
      IntentionDraft(
        portfolioId: widget.portfolioId,
        title: _title.text,
        targetMinor: minor,
        targetDate: date,
        status: current.status,
      ),
    );
  }
}

class _CreateIntentionForm extends StatelessWidget {
  const _CreateIntentionForm({
    required this.title,
    required this.target,
    required this.date,
    required this.sourceLabel,
    required this.review,
    required this.draft,
    required this.onReview,
    required this.onConfirm,
    required this.onCancel,
  });

  final TextEditingController title;
  final TextEditingController target;
  final TextEditingController date;
  final String sourceLabel;
  final bool review;
  final IntentionDraft? draft;
  final VoidCallback onReview;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create an Intention',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Your profile goal and horizon shaped these editable starting values.',
          ),
          Text(sourceLabel, key: const Key('intention-personalization-source')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('intention-title'),
            controller: title,
            enabled: !review,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Goal title'),
          ),
          TextField(
            key: const Key('intention-target'),
            controller: target,
            enabled: !review,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target amount (Demo USD)',
            ),
          ),
          TextField(
            key: const Key('intention-target-date'),
            controller: date,
            enabled: !review,
            decoration: const InputDecoration(
              labelText: 'Target date (YYYY-MM-DD)',
            ),
          ),
          const SizedBox(height: 8),
          if (review && draft != null) ...[
            const Text('Review: this tracks a fictional Demo goal only.'),
            FilledButton(
              key: const Key('intention-confirm-create'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onConfirm,
              child: const Text('Confirm Demo goal'),
            ),
          ] else
            FilledButton(
              key: const Key('intention-review-create'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onReview,
              child: const Text('Review goal'),
            ),
          TextButton(onPressed: onCancel, child: const Text('Close editor')),
        ],
      ),
    ),
  );
}

class _EditIntentionForm extends StatelessWidget {
  const _EditIntentionForm({
    required this.title,
    required this.target,
    required this.date,
    required this.review,
    required this.onReview,
    required this.onConfirm,
  });

  final TextEditingController title;
  final TextEditingController target;
  final TextEditingController date;
  final bool review;
  final VoidCallback onReview;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            key: const Key('intention-edit-title'),
            controller: title,
            enabled: !review,
          ),
          TextField(
            key: const Key('intention-edit-target'),
            controller: target,
            enabled: !review,
          ),
          TextField(
            key: const Key('intention-edit-date'),
            controller: date,
            enabled: !review,
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: Key(
              review ? 'intention-confirm-edit' : 'intention-review-edit',
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: review ? onConfirm : onReview,
            child: Text(review ? 'Confirm changes' : 'Review changes'),
          ),
        ],
      ),
    ),
  );
}

class _IntentionsDisclosure extends StatelessWidget {
  const _IntentionsDisclosure();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'DEMO · USD · provider-free. Intentions and progress use fictional ledger activity. '
        'They are educational planning tools, not investment advice or a promise of results. No real money moves.',
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: onPressed,
    child: Text(label),
  );
}

String _statusLabel(IntentionStatus status) => switch (status) {
  IntentionStatus.active => 'Active',
  IntentionStatus.completed => 'Completed',
  IntentionStatus.archived => 'Archived',
};

String _dateOnly(DateTime value) =>
    '${value.toUtc().year.toString().padLeft(4, '0')}-'
    '${value.toUtc().month.toString().padLeft(2, '0')}-'
    '${value.toUtc().day.toString().padLeft(2, '0')}';

DateTime? _parseDate(String raw) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw.trim())) return null;
  final value = DateTime.tryParse('${raw.trim()}T00:00:00Z');
  return value?.isUtc == true && _dateOnly(value!) == raw.trim() ? value : null;
}

int? _usdMinor(String raw) {
  final value = raw.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  final cents = int.tryParse((match.group(2) ?? '').padRight(2, '0')) ?? 0;
  if (whole == null) return null;
  final minor = whole * 100 + cents;
  return minor >= 1 && minor <= 1000000000 ? minor : null;
}
