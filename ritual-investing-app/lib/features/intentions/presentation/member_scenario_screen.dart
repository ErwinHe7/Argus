import 'package:flutter/material.dart';

import '../application/member_scenario_controller.dart';
import '../domain/member_scenario_model.dart';

class MemberScenariosScreen extends StatefulWidget {
  const MemberScenariosScreen({
    super.key,
    required this.controller,
    this.intentionId,
    this.runId,
    this.onOpenIntention,
    this.onOpenRun,
  });

  final MemberScenarioController controller;
  final String? intentionId;
  final String? runId;
  final ValueChanged<String>? onOpenIntention;
  final ValueChanged<String>? onOpenRun;

  @override
  State<MemberScenariosScreen> createState() => _MemberScenariosScreenState();
}

class _MemberScenariosScreenState extends State<MemberScenariosScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final intentionId = widget.intentionId;
    if (intentionId == null) {
      await widget.controller.load();
      return;
    }
    await widget.controller.openIntention(intentionId);
    final runId = widget.runId;
    if (runId != null) await widget.controller.openRun(runId);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.intentionId == null ? 'Intentions' : 'Intention'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: state.phase == MemberScenarioPhase.saving
                  ? null
                  : widget.controller.refreshSelected,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: widget.intentionId == null
            ? FloatingActionButton.extended(
                onPressed: () => _showIntentionEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('New Intention'),
              )
            : null,
        body: SafeArea(
          child: switch (state.phase) {
            MemberScenarioPhase.idle || MemberScenarioPhase.loading =>
              const Center(child: CircularProgressIndicator()),
            _ => RefreshIndicator(
              onRefresh: widget.controller.refreshSelected,
              child: widget.intentionId == null
                  ? _IntentionList(state: state, onOpen: widget.onOpenIntention)
                  : _IntentionDetail(
                      state: state,
                      onEdit: () => _showIntentionEditor(
                        context,
                        existing: state.selectedIntention,
                      ),
                      onArchive: widget.controller.archiveSelected,
                      onReviewMirror: (input) =>
                          _reviewFutureMirror(context, input),
                    ),
            ),
          },
        ),
      );
    },
  );

  Future<void> _showIntentionEditor(
    BuildContext context, {
    MemberIntentionScenario? existing,
  }) async {
    final input = await showDialog<MemberIntentionInput>(
      context: context,
      builder: (context) => _IntentionEditor(existing: existing),
    );
    if (input == null) return;
    if (existing == null) {
      await widget.controller.createIntention(input);
    } else {
      await widget.controller.patchSelected(input);
    }
  }

  Future<void> _reviewFutureMirror(
    BuildContext context,
    HypotheticalScenarioInput input,
  ) async {
    widget.controller.reviewFutureMirror(input);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ScenarioReview(input: input),
    );
    if (confirmed == true) {
      await widget.controller.confirmFutureMirror();
    } else {
      widget.controller.cancelReview();
    }
  }
}

class _IntentionList extends StatelessWidget {
  const _IntentionList({required this.state, required this.onOpen});

  final MemberScenarioState state;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
    children: [
      const Text(
        'Your Intentions are member-entered goals. They are independent of any brokerage account.',
      ),
      if (state.message case final message?) ...[
        const SizedBox(height: 12),
        _StatusCard(message: message, phase: state.phase),
      ],
      const SizedBox(height: 16),
      if (state.intentions.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No Intentions yet. Add one to explore a scenario.'),
          ),
        )
      else
        for (final intention in state.intentions)
          Card(
            child: ListTile(
              title: Text(intention.title),
              subtitle: Text(
                '${_money(intention.target)} · target ${_date(intention.targetDate)}'
                '${intention.status == MemberIntentionStatus.archived ? ' · archived' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpen == null ? null : () => onOpen!(intention.id),
            ),
          ),
    ],
  );
}

class _IntentionDetail extends StatefulWidget {
  const _IntentionDetail({
    required this.state,
    required this.onEdit,
    required this.onArchive,
    required this.onReviewMirror,
  });

  final MemberScenarioState state;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final ValueChanged<HypotheticalScenarioInput> onReviewMirror;

  @override
  State<_IntentionDetail> createState() => _IntentionDetailState();
}

class _IntentionDetailState extends State<_IntentionDetail> {
  final _name = TextEditingController(text: 'My hypothetical scenario');
  final _baseline = TextEditingController(text: '0');
  final _monthly = TextEditingController(text: '0');
  final _currency = TextEditingController(text: 'USD');
  final _low = TextEditingController(text: '-100');
  final _mid = TextEditingController(text: '300');
  final _high = TextEditingController(text: '500');

  @override
  void dispose() {
    _name.dispose();
    _baseline.dispose();
    _monthly.dispose();
    _currency.dispose();
    _low.dispose();
    _mid.dispose();
    _high.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intention = widget.state.selectedIntention;
    if (intention == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 240)],
      );
    }
    final mirror = widget.state.futureMirror;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(intention.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('${_money(intention.target)} by ${_date(intention.targetDate)}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            if (intention.status == MemberIntentionStatus.active) ...[
              OutlinedButton(
                onPressed: widget.onEdit,
                child: const Text('Edit'),
              ),
              OutlinedButton(
                onPressed: widget.onArchive,
                child: const Text('Archive'),
              ),
            ],
          ],
        ),
        if (widget.state.message case final message?) ...[
          const SizedBox(height: 12),
          _StatusCard(message: message, phase: widget.state.phase),
        ],
        const SizedBox(height: 24),
        Text('Future Mirror', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'A deterministic hypothetical scenario based only on values you enter. It is not a forecast, advice, or a view of brokerage holdings or performance.',
        ),
        if (mirror case final value?) ...[
          const SizedBox(height: 16),
          _MirrorCard(mirror: value),
        ],
        if (intention.status == MemberIntentionStatus.active) ...[
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Scenario name'),
          ),
          TextField(
            controller: _baseline,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Member-entered baseline (minor units)',
            ),
          ),
          TextField(
            controller: _monthly,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monthly contribution assumption (minor units)',
            ),
          ),
          TextField(
            controller: _currency,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Currency code'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _low,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Low bps'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _mid,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mid bps'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _high,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'High bps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.state.phase == MemberScenarioPhase.saving
                ? null
                : _review,
            child: const Text('Review exact assumptions'),
          ),
        ],
      ],
    );
  }

  void _review() {
    final low = int.tryParse(_low.text);
    final mid = int.tryParse(_mid.text);
    final high = int.tryParse(_high.text);
    final currency = _currency.text.trim().toUpperCase();
    if (_name.text.trim().isEmpty ||
        _name.text.trim().length > 80 ||
        !_minor(_baseline.text) ||
        !_minor(_monthly.text) ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        low == null ||
        mid == null ||
        high == null ||
        low < -5000 ||
        high > 5000 ||
        low > mid ||
        mid > high) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check the exact amounts, currency, and ordered return bands.',
          ),
        ),
      );
      return;
    }
    final now = DateTime.now().toUtc();
    widget.onReviewMirror(
      HypotheticalScenarioInput(
        name: _name.text.trim(),
        baseline: ExactScenarioMoney(
          minorUnits: _baseline.text.trim(),
          currency: currency,
        ),
        monthlyContribution: ExactScenarioMoney(
          minorUnits: _monthly.text.trim(),
          currency: currency,
        ),
        lowReturnBps: low,
        midReturnBps: mid,
        highReturnBps: high,
        asOfDate: DateTime.utc(now.year, now.month, now.day),
      ),
    );
  }
}

class _MirrorCard extends StatelessWidget {
  const _MirrorCard({required this.mirror});

  final HypotheticalFutureScenario mirror;

  @override
  Widget build(BuildContext context) {
    final last = mirror.points.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mirror.input.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(mirror.uncertaintyDisclosure),
            const SizedBox(height: 12),
            Text(
              'At ${_date(last.date)} · low ${last.lowMinor} · mid ${last.midMinor} · high ${last.highMinor} minor units',
            ),
            Text(
              'Model ${mirror.modelVersion} · assumptions ${mirror.assumptionVersion}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioReview extends StatelessWidget {
  const _ScenarioReview({required this.input});

  final HypotheticalScenarioInput input;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review hypothetical assumptions'),
    content: SingleChildScrollView(
      child: Text(
        '${input.name}\n\nBaseline: ${_money(input.baseline)}\nMonthly contribution: ${_money(input.monthlyContribution)}\nAnnual return bands: ${input.lowReturnBps}, ${input.midReturnBps}, ${input.highReturnBps} bps\nAs of: ${_date(input.asOfDate)}\n\nThese are member-entered assumptions, not brokerage facts. Results are hypothetical and uncertain.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Change'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Generate scenario'),
      ),
    ],
  );
}

class _IntentionEditor extends StatefulWidget {
  const _IntentionEditor({this.existing});

  final MemberIntentionScenario? existing;

  @override
  State<_IntentionEditor> createState() => _IntentionEditorState();
}

class _IntentionEditorState extends State<_IntentionEditor> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _currency;
  late final TextEditingController _date;

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _title = TextEditingController(text: value?.title ?? '');
    _amount = TextEditingController(text: value?.target.minorUnits ?? '');
    _currency = TextEditingController(text: value?.target.currency ?? 'USD');
    _date = TextEditingController(
      text: value == null ? '' : _dateValue(value.targetDate),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _currency.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'New Intention' : 'Edit Intention'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target (minor units)',
            ),
          ),
          TextField(
            controller: _currency,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Currency code'),
          ),
          TextField(
            controller: _date,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Future target date (YYYY-MM-DD)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

  void _save() {
    final targetDate = _futureDateOnly(_date.text.trim());
    final currency = _currency.text.trim().toUpperCase();
    if (_title.text.trim().isEmpty ||
        !_minor(_amount.text) ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        targetDate == null) {
      return;
    }
    Navigator.pop(
      context,
      MemberIntentionInput(
        title: _title.text.trim(),
        target: ExactScenarioMoney(
          minorUnits: _amount.text.trim(),
          currency: currency,
        ),
        targetDate: DateTime.utc(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message, required this.phase});

  final String message;
  final MemberScenarioPhase phase;

  @override
  Widget build(BuildContext context) => Card(
    color: phase == MemberScenarioPhase.ambiguous
        ? Theme.of(context).colorScheme.tertiaryContainer
        : Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}

bool _minor(String value) {
  final normalized = value.trim();
  const maximum = '9007199254740991';
  return RegExp(r'^(0|[1-9][0-9]{0,15})$').hasMatch(normalized) &&
      (normalized.length < maximum.length ||
          normalized.compareTo(maximum) <= 0);
}

DateTime? _futureDateOnly(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || _dateValue(parsed) != value) return null;
  final now = DateTime.now().toUtc();
  final today = DateTime.utc(now.year, now.month, now.day);
  return parsed.isAfter(today) ? parsed : null;
}

String _money(ExactScenarioMoney value) =>
    '${value.currency} ${value.minorUnits} minor units';

String _date(DateTime value) => _dateValue(value);

String _dateValue(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
