import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../funding/application/funding_source_controller.dart';
import '../../funding/domain/model.dart';
import '../../portfolio/application/controller.dart';
import '../../portfolio/domain/model.dart';
import '../application/recurring_plan_controller.dart';
import '../domain/model.dart';

const _controlStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(48, 48)),
  tapTargetSize: MaterialTapTargetSize.padded,
);

class RecurringPlansScreen extends StatefulWidget {
  const RecurringPlansScreen({
    super.key,
    required this.portfolioId,
    required this.controller,
    required this.portfolioController,
    required this.fundingSourceController,
    this.onOpenPlan,
  });

  final String portfolioId;
  final RecurringPlanController controller;
  final PortfolioController portfolioController;
  final FundingSourceController fundingSourceController;
  final ValueChanged<String>? onOpenPlan;

  @override
  State<RecurringPlansScreen> createState() => _RecurringPlansScreenState();
}

class _RecurringPlansScreenState extends State<RecurringPlansScreen> {
  final _amount = TextEditingController(text: '25.00');
  RecurringType _type = RecurringType.contribution;
  late RecurringFrequency _frequency;
  DateTime _firstRunAt = DateTime.now().toUtc().add(const Duration(days: 7));
  String? _sourceId;
  String? _assetId;

  @override
  void initState() {
    super.initState();
    _frequency = widget.controller.defaults.frequency;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_hydrate());
    });
  }

  Future<void> _hydrate() async {
    await Future.wait([
      widget.controller.openPortfolio(widget.portfolioId),
      widget.portfolioController.open(widget.portfolioId),
      widget.fundingSourceController.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _assetId ??= widget
          .portfolioController
          .detailState
          .value
          ?.holdings
          .firstOrNull
          ?.assetId;
      _sourceId ??= widget.fundingSourceController.state.value?.items
          .where((source) => source.isActive)
          .firstOrNull
          ?.id;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.portfolioController,
      widget.fundingSourceController,
    ]),
    builder: (context, _) {
      final holdings =
          widget.portfolioController.detailState.value?.holdings ??
          const <PortfolioHolding>[];
      final sources =
          widget.fundingSourceController.state.value?.items
              .where((source) => source.isActive)
              .toList(growable: false) ??
          const <FundingSource>[];
      final selectedAsset =
          holdings.any((holding) => holding.assetId == _assetId)
          ? _assetId
          : holdings.firstOrNull?.assetId;
      final selectedSource = sources.any((source) => source.id == _sourceId)
          ? _sourceId
          : sources.firstOrNull?.id;
      final draft = widget.controller.createDraft;
      final reviewing =
          draft != null &&
          {
            RecurringCommandPhase.createReview,
            RecurringCommandPhase.restoredReview,
            RecurringCommandPhase.retryableFailure,
            RecurringCommandPhase.throttled,
          }.contains(widget.controller.phase);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Recurring plans'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: DemoBadge(horizontalPadding: 9)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Provider-free Demo scheduler · Fictional sources only. No bank credentials, brokerage, provider, or real money is connected.',
              ),
              const SizedBox(height: 20),
              if (reviewing) ...[
                Text(
                  'Review recurring schedule',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${draft.type.name} · ${MinorMoney.usd(draft.amountMinor)}',
                ),
                Text(
                  '${draft.frequency.name} · first run ${draft.firstRunAt.toLocal()}',
                ),
                Text(
                  'Allocation ${_assetLabel(draft.allocations.first.assetId, holdings)} · '
                  '${(draft.allocations.first.weightBps / 100).toStringAsFixed(2)}%',
                ),
                if (_sourceLabel(draft.sourceId, sources) case final source?)
                  Text('Selected fictional source for this review: $source'),
                const Text(
                  'The source choice is checked again at confirmation and is not returned as authoritative plan detail by the API.',
                ),
                if (widget.controller.phase ==
                    RecurringCommandPhase.createReview)
                  FilledButton(
                    key: const Key('confirm-recurring-create'),
                    style: _controlStyle,
                    onPressed: widget.controller.isMutating
                        ? null
                        : () => unawaited(widget.controller.confirmCreate()),
                    child: const Text('Confirm Demo recurring plan'),
                  )
                else
                  FilledButton(
                    key: const Key('review-saved-recurring'),
                    style: _controlStyle,
                    onPressed: widget.controller.reviewRestoredCreate,
                    child: const Text('Review unchanged saved plan'),
                  ),
                if (widget.controller.phase ==
                        RecurringCommandPhase.restoredReview ||
                    widget.controller.phase ==
                        RecurringCommandPhase.retryableFailure)
                  TextButton(
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.discardPendingCreate()),
                    child: const Text('Discard saved confirmation'),
                  ),
              ] else ...[
                Text(
                  'Create an editable schedule',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(widget.controller.defaults.label),
                DropdownButtonFormField<RecurringType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Plan type'),
                  items: RecurringType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                TextField(
                  key: const Key('recurring-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Demo amount (USD)',
                  ),
                ),
                DropdownButtonFormField<RecurringFrequency>(
                  initialValue: _frequency,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cadence'),
                  items: RecurringFrequency.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _frequency = value ?? _frequency),
                ),
                KeyedSubtree(
                  key: ValueKey('recurring-source-$selectedSource'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('recurring-source'),
                    isExpanded: true,
                    initialValue: selectedSource,
                    decoration: const InputDecoration(
                      labelText: 'Fictional funding source',
                    ),
                    items: sources
                        .map(
                          (source) => DropdownMenuItem(
                            value: source.id,
                            child: Text(
                              source.displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: sources.isEmpty
                        ? null
                        : (value) => setState(() => _sourceId = value),
                  ),
                ),
                KeyedSubtree(
                  key: ValueKey('recurring-asset-$selectedAsset'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('recurring-asset'),
                    isExpanded: true,
                    initialValue: selectedAsset,
                    decoration: const InputDecoration(
                      labelText: 'Demo allocation asset',
                      helperText:
                          'Chosen from this portfolio’s labeled holdings.',
                    ),
                    items: holdings
                        .map(
                          (holding) => DropdownMenuItem(
                            value: holding.assetId,
                            child: Text(
                              holding.symbol,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: holdings.isEmpty
                        ? null
                        : (value) => setState(() => _assetId = value),
                  ),
                ),
                ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('First Demo run'),
                  subtitle: Text(_firstRunAt.toLocal().toString()),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _chooseFirstRun,
                ),
                if (sources.isEmpty || holdings.isEmpty)
                  const Text(
                    'An active fictional source and a labeled holding are required before review.',
                  ),
                FilledButton(
                  key: const Key('review-recurring-create'),
                  style: _controlStyle,
                  onPressed: selectedSource == null || selectedAsset == null
                      ? null
                      : () => unawaited(
                          widget.controller.prepareCreate(
                            RecurringPlanDraft(
                              portfolioId: widget.portfolioId,
                              sourceId: selectedSource,
                              type: _type,
                              amountMinor: _minorUnits(_amount.text) ?? 0,
                              frequency: _frequency,
                              firstRunAt: _firstRunAt,
                              allocations: [
                                RecurringAllocation(
                                  assetId: selectedAsset,
                                  weightBps: 10000,
                                ),
                              ],
                            ),
                            sourceIsActive: true,
                          ),
                        ),
                  child: const Text('Review recurring plan'),
                ),
              ],
              if (widget.controller.phase ==
                  RecurringCommandPhase.reconciliationRequired)
                FilledButton(
                  style: _controlStyle,
                  onPressed: () =>
                      unawaited(widget.controller.retryReconciliation()),
                  child: const Text('Refresh plans and fictional source'),
                ),
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 8),
                Text(message),
              ],
              const Divider(height: 40),
              Text(
                'Authoritative schedules',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.controller.plans.isEmpty)
                const Text('No recurring Demo plans yet.'),
              for (final plan in widget.controller.plans)
                ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${plan.frequency.name} · ${MinorMoney.usd(plan.amountMinor)}',
                  ),
                  subtitle: Text(
                    '${plan.status.name} · next ${plan.nextRunAt.toLocal()}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onOpenPlan == null
                      ? null
                      : () => widget.onOpenPlan!(plan.id),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _chooseFirstRun() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _firstRunAt.toLocal(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _firstRunAt = DateTime(date.year, date.month, date.day, 9, 30).toUtc();
    });
  }
}

class RecurringPlanDetailScreen extends StatefulWidget {
  const RecurringPlanDetailScreen({
    super.key,
    required this.portfolioId,
    required this.planId,
    required this.controller,
    required this.portfolioController,
  });

  final String portfolioId;
  final String planId;
  final RecurringPlanController controller;
  final PortfolioController portfolioController;

  @override
  State<RecurringPlanDetailScreen> createState() =>
      _RecurringPlanDetailScreenState();
}

class _RecurringPlanDetailScreenState extends State<RecurringPlanDetailScreen> {
  final _amount = TextEditingController();
  RecurringFrequency? _frequency;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(() async {
        await widget.controller.openPortfolio(widget.portfolioId);
        await widget.portfolioController.open(widget.portfolioId);
        await widget.controller.openPlan(widget.planId);
      }());
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.portfolioController,
    ]),
    builder: (context, _) {
      final plan = widget.controller.selected;
      final holdings =
          widget.portfolioController.detailState.value?.holdings ??
          const <PortfolioHolding>[];
      return Scaffold(
        appBar: AppBar(title: const Text('Recurring plan')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const DemoBadge(),
              const Text(
                'The API does not return funding-source identity for an existing plan. Status, next run, version, and recent runs below are authoritative.',
              ),
              if (plan == null)
                const Text('Loading authoritative Demo schedule…')
              else ...[
                Text(
                  '${plan.frequency.name} · ${MinorMoney.usd(plan.amountMinor)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('Status ${plan.status.name} · version ${plan.version}'),
                Text('Next run ${plan.nextRunAt.toLocal()}'),
                for (final allocation in plan.allocations)
                  Text(
                    '${_assetLabel(allocation.assetId, holdings)} · '
                    '${(allocation.weightBps / 100).toStringAsFixed(2)}%',
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'New Demo amount (optional)',
                    hintText: (plan.amountMinor / 100).toStringAsFixed(2),
                  ),
                ),
                DropdownButtonFormField<RecurringFrequency>(
                  initialValue: _frequency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'New cadence (optional)',
                  ),
                  items: RecurringFrequency.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _frequency = value),
                ),
                if (widget.controller.phase ==
                        RecurringCommandPhase.editReview ||
                    (widget.controller.phase ==
                            RecurringCommandPhase.conflictReview &&
                        widget.controller.editDraft != null)) ...[
                  Text(
                    'Review change against authoritative plan v${plan.version}.',
                  ),
                  FilledButton(
                    key: const Key('confirm-recurring-edit'),
                    style: _controlStyle,
                    onPressed:
                        widget.controller.phase ==
                            RecurringCommandPhase.conflictReview
                        ? widget.controller.reviewEditAgainstAuthority
                        : () => unawaited(widget.controller.confirmEdit()),
                    child: Text(
                      widget.controller.phase ==
                              RecurringCommandPhase.conflictReview
                          ? 'Review against refreshed version'
                          : 'Confirm Demo plan changes',
                    ),
                  ),
                ] else
                  FilledButton(
                    key: const Key('review-recurring-edit'),
                    style: _controlStyle,
                    onPressed: () => widget.controller.prepareEdit(
                      amountMinor: _amount.text.trim().isEmpty
                          ? null
                          : _minorUnits(_amount.text),
                      frequency: _frequency,
                    ),
                    child: const Text('Review schedule changes'),
                  ),
                const SizedBox(height: 16),
                if (plan.status == RecurringStatus.active)
                  OutlinedButton(
                    style: _controlStyle,
                    onPressed: () => unawaited(widget.controller.pause()),
                    child: const Text('Pause Demo plan'),
                  ),
                if (plan.status == RecurringStatus.paused)
                  OutlinedButton(
                    style: _controlStyle,
                    onPressed: () => unawaited(widget.controller.resume()),
                    child: const Text('Resume Demo plan'),
                  ),
                if (plan.status != RecurringStatus.cancelled &&
                    plan.status != RecurringStatus.completed)
                  TextButton(
                    style: _controlStyle,
                    onPressed: _confirmCancel,
                    child: const Text('Cancel recurring plan'),
                  ),
                const Divider(height: 32),
                Text(
                  'Recent authoritative runs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (plan.recentRuns.isEmpty)
                  const Text('No runs recorded yet.'),
                for (final run in plan.recentRuns)
                  ListTile(
                    minTileHeight: 48,
                    contentPadding: EdgeInsets.zero,
                    title: Text(run.status.name),
                    subtitle: Text(run.scheduledFor.toLocal().toString()),
                  ),
                Text(plan.demo.limitations.join(' ')),
              ],
              if (widget.controller.phase ==
                  RecurringCommandPhase.reconciliationRequired)
                FilledButton(
                  style: _controlStyle,
                  onPressed: () =>
                      unawaited(widget.controller.retryReconciliation()),
                  child: const Text('Refresh authoritative plan'),
                ),
              if (widget.controller.message case final message?) Text(message),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel recurring Demo plan?'),
        content: const Text(
          'Cancellation is terminal. The API retains prior immutable runs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            key: const Key('confirm-recurring-cancel'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.cancel();
  }
}

String _assetLabel(String assetId, List<PortfolioHolding> holdings) =>
    holdings
        .where((holding) => holding.assetId == assetId)
        .map((holding) => holding.symbol)
        .firstOrNull ??
    'Demo asset';

String? _sourceLabel(String sourceId, List<FundingSource> sources) => sources
    .where((source) => source.id == sourceId)
    .map((source) => source.displayLabel)
    .firstOrNull;

int? _minorUnits(String input) {
  final match = RegExp(r'^\s*(\d{1,8})(?:\.(\d{1,2}))?\s*$').firstMatch(input);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 100 +
      int.parse((match.group(2) ?? '').padRight(2, '0'));
}
