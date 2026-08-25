import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/state_status.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../funding/application/contribution_controller.dart';
import '../../funding/application/funding_source_controller.dart';
import '../../funding/domain/model.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.portfolioId,
    required this.portfolioController,
    required this.fundingSourceController,
    required this.contributionController,
    this.onOpenPortfolio,
    this.onOpenAsset,
    this.onOpenOrders,
    this.onOpenRecurringPlans,
    this.onOpenRebalance,
  });

  final String portfolioId;
  final PortfolioController portfolioController;
  final FundingSourceController fundingSourceController;
  final ContributionController contributionController;
  final ValueChanged<String>? onOpenPortfolio;
  final ValueChanged<String>? onOpenAsset;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenRecurringPlans;
  final VoidCallback? onOpenRebalance;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final TextEditingController _amountController;
  String? _sourceId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (widget.contributionController.defaults.minorUnits / 100)
          .toStringAsFixed(2),
    );
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    await Future.wait([
      widget.portfolioController.open(widget.portfolioId),
      widget.fundingSourceController.load(),
    ]);
    await widget.contributionController.openPortfolio(widget.portfolioId);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.portfolioController,
      widget.fundingSourceController,
      widget.contributionController,
    ]),
    builder: (context, _) {
      final detail = widget.portfolioController.detailState.value;
      final sources =
          widget.fundingSourceController.state.value?.items
              .where((source) => source.isActive)
              .toList(growable: false) ??
          const <FundingSource>[];
      final selectedSource = sources.any((source) => source.id == _sourceId)
          ? _sourceId
          : sources.firstOrNull?.id;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Portfolio'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: DemoBadge(horizontalPadding: 9)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const _PersistentDisclosure(),
              const SizedBox(height: 16),
              _PortfolioChooser(
                controller: widget.portfolioController,
                onSelect: (id) {
                  final navigate = widget.onOpenPortfolio;
                  if (navigate != null) {
                    navigate(id);
                  } else {
                    unawaited(widget.portfolioController.open(id));
                  }
                },
                onCreate: () => _showNameDialog(create: true),
              ),
              StateStatus(
                phase: widget.portfolioController.detailState.phase,
                onRetry: () => unawaited(
                  widget.portfolioController.open(
                    widget.portfolioController.selectedPortfolioId ??
                        widget.portfolioId,
                  ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 12),
                _PortfolioHeader(detail.portfolio),
                const SizedBox(height: 16),
                _ManagePortfolio(
                  controller: widget.portfolioController,
                  onRename: () => _showNameDialog(
                    create: false,
                    initial: detail.portfolio.name,
                  ),
                  onArchive: _confirmArchive,
                ),
                if (widget.onOpenOrders != null ||
                    widget.onOpenRecurringPlans != null ||
                    widget.onOpenRebalance != null) ...[
                  const SizedBox(height: 24),
                  _SimulationActions(
                    onOpenOrders: widget.onOpenOrders,
                    onOpenRecurringPlans: widget.onOpenRecurringPlans,
                    onOpenRebalance: widget.onOpenRebalance,
                  ),
                ],
                const SizedBox(height: 24),
                _PortfolioReads(
                  detail: detail,
                  onOpenAsset: widget.onOpenAsset,
                ),
                const SizedBox(height: 28),
                _FundingSources(
                  controller: widget.fundingSourceController,
                  sources: sources,
                  selectedId: selectedSource,
                  onSelected: (value) => setState(() => _sourceId = value),
                  onDelete: _confirmFundingDelete,
                ),
                const SizedBox(height: 28),
                _ContributionPanel(
                  controller: widget.contributionController,
                  portfolioId: detail.portfolio.id,
                  sourceId: selectedSource,
                  amountController: _amountController,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Future<void> _showNameDialog({
    required bool create,
    String initial = '',
  }) async {
    final input = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(create ? 'Create Demo portfolio' : 'Rename portfolio'),
        content: TextField(
          key: Key(create ? 'portfolio-create-name' : 'portfolio-rename-name'),
          controller: input,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Portfolio name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: Text(create ? 'Create' : 'Save name'),
          ),
        ],
      ),
    );
    input.dispose();
    if (value == null || !mounted) return;
    if (create) {
      await widget.portfolioController.create(value);
    } else {
      await widget.portfolioController.renameSelected(value);
    }
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Demo portfolio?'),
        content: const Text(
          'The server will enforce default-portfolio and recurring-plan protections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('portfolio-archive-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.portfolioController.archiveSelected();
  }

  Future<void> _confirmFundingDelete(String sourceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fictional source?'),
        content: const Text(
          'The server will keep it if an active recurring plan still uses it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('funding-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete source'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.fundingSourceController.delete(sourceId);
    }
  }
}

class _PersistentDisclosure extends StatelessWidget {
  const _PersistentDisclosure();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Demo provider-free investing. No real money, bank, brokerage, or payment provider is connected.',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Provider-free Demo · No real money moves. Balances, sources, and receipts are fictional authoritative scenarios.',
        ),
      ),
    ),
  );
}

class _PortfolioChooser extends StatelessWidget {
  const _PortfolioChooser({
    required this.controller,
    required this.onSelect,
    required this.onCreate,
  });

  final PortfolioController controller;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final items = controller.state.value?.items ?? const <PortfolioSummary>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your Demo portfolios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              key: const Key('portfolio-create'),
              style: _controlStyle,
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
          ],
        ),
        for (final item in items)
          ListTile(
            minTileHeight: 48,
            leading: Icon(
              controller.selectedPortfolioId == item.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            onTap: item.isActive ? () => onSelect(item.id) : null,
            title: Text(item.name),
            subtitle: Text(
              '${item.isDefault ? 'Default · ' : ''}${item.status.name} · v${item.version}',
            ),
          ),
        if (controller.pendingCreateName case final name?)
          _PendingCommandActions(
            text: 'Pending portfolio: $name',
            retryKey: const Key('portfolio-create-retry'),
            discardKey: const Key('portfolio-create-discard'),
            onRetry: () => unawaited(controller.retryPendingCreate()),
            onDiscard: controller.discardPendingCreate,
          ),
        if (controller.message case final message?) Text(message),
      ],
    );
  }
}

class _PortfolioHeader extends StatelessWidget {
  const _PortfolioHeader(this.portfolio);
  final PortfolioSummary portfolio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        portfolio.name,
        key: const Key('portfolio-detail-name'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      if (portfolio.isDefault) const Chip(label: Text('Default portfolio')),
      const SizedBox(height: 12),
      Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _Metric(
            label: 'Demo cash',
            value: MinorMoney.usd(portfolio.cashMinor),
          ),
          _Metric(
            label: 'Demo valuation',
            value: MinorMoney.usd(portfolio.valuationMinor),
          ),
          _Metric(
            label: 'Ledger watermark',
            value: '${portfolio.ledgerWatermark}',
          ),
          _Metric(label: 'Version', value: 'v${portfolio.version}'),
        ],
      ),
      const SizedBox(height: 8),
      Text(portfolio.demo.limitations.join(' ')),
    ],
  );
}

class _ManagePortfolio extends StatelessWidget {
  const _ManagePortfolio({
    required this.controller,
    required this.onRename,
    required this.onArchive,
  });
  final PortfolioController controller;
  final VoidCallback onRename;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('portfolio-rename'),
            style: _controlStyle,
            onPressed: controller.isMutating ? null : onRename,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Rename'),
          ),
          OutlinedButton.icon(
            key: const Key('portfolio-archive'),
            style: _controlStyle,
            onPressed: controller.isMutating ? null : onArchive,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        ],
      ),
      if (controller.requiresConflictReview)
        FilledButton(
          key: const Key('portfolio-rename-review-retry'),
          style: _controlStyle,
          onPressed: () => unawaited(controller.reviewAndRetryRename()),
          child: const Text('Review and retry name'),
        ),
      if (controller.pendingName != null && !controller.requiresConflictReview)
        OutlinedButton(
          key: const Key('portfolio-rename-refresh'),
          style: _controlStyle,
          onPressed: () => unawaited(controller.refreshRenameAuthority()),
          child: const Text('Refresh before retrying name'),
        ),
      if (controller.requiresArchiveReview)
        FilledButton(
          key: const Key('portfolio-archive-review-retry'),
          style: _controlStyle,
          onPressed: () => unawaited(controller.reviewAndRetryArchive()),
          child: const Text('Review and retry archive'),
        ),
    ],
  );
}

class _SimulationActions extends StatelessWidget {
  const _SimulationActions({
    this.onOpenOrders,
    this.onOpenRecurringPlans,
    this.onOpenRebalance,
  });

  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenRecurringPlans;
  final VoidCallback? onOpenRebalance;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Practice investing', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Provider-free Demo commands use fictional prices and ledger entries. No real money moves.',
      ),
      const SizedBox(height: 10),
      if (onOpenOrders != null)
        FilledButton.icon(
          key: const Key('open-demo-orders'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onOpenOrders,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Orders'),
        ),
      if (onOpenRecurringPlans != null)
        OutlinedButton.icon(
          key: const Key('open-recurring-plans'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onOpenRecurringPlans,
          icon: const Icon(Icons.event_repeat_outlined),
          label: const Text('Recurring plans'),
        ),
      if (onOpenRebalance != null)
        OutlinedButton.icon(
          key: const Key('open-rebalance'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onOpenRebalance,
          icon: const Icon(Icons.balance_outlined),
          label: const Text('Rebalance'),
        ),
    ],
  );
}

class _PortfolioReads extends StatelessWidget {
  const _PortfolioReads({required this.detail, required this.onOpenAsset});
  final PortfolioDetail detail;
  final ValueChanged<String>? onOpenAsset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Holdings', style: Theme.of(context).textTheme.titleLarge),
      if (detail.holdings.isEmpty) const Text('No Demo holdings yet.'),
      for (final holding in detail.holdings)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(holding.symbol),
          subtitle: Text(
            '${holding.quantityValue} · watermark ${holding.ledgerWatermark}',
          ),
          trailing: Text(MinorMoney.usd(holding.marketValueMinor)),
          onTap: onOpenAsset == null
              ? null
              : () => onOpenAsset!(holding.assetId),
        ),
      const SizedBox(height: 16),
      Text('Activity', style: Theme.of(context).textTheme.titleLarge),
      if (detail.activity.isEmpty) const Text('No Demo activity yet.'),
      for (final item in detail.activity)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.descriptionCode.replaceAll('_', ' ')),
          subtitle: Text(
            '${item.type.name} · watermark ${item.ledgerWatermark}',
          ),
          trailing: Text(MinorMoney.usd(item.cashMinor)),
        ),
      const SizedBox(height: 16),
      Text('Valuation history', style: Theme.of(context).textTheme.titleLarge),
      if (detail.snapshots.isEmpty) const Text('No Demo snapshots yet.'),
      for (final item in detail.snapshots)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(MinorMoney.usd(item.marketValueMinor + item.cashMinor)),
          subtitle: Text(
            '${item.asOf.toLocal().toIso8601String()} · watermark ${item.ledgerWatermark}',
          ),
        ),
    ],
  );
}

class _FundingSources extends StatelessWidget {
  const _FundingSources({
    required this.controller,
    required this.sources,
    required this.selectedId,
    required this.onSelected,
    required this.onDelete,
  });
  final FundingSourceController controller;
  final List<FundingSource> sources;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Fictional funding sources',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Choose a fixed Demo fixture. No bank, card, account, or credential details are collected.',
      ),
      StateStatus(phase: controller.state.phase, onRetry: controller.load),
      for (final source in sources)
        ListTile(
          minTileHeight: 48,
          leading: Icon(
            selectedId == source.id
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
          ),
          onTap: () => onSelected(source.id),
          title: Text(
            '${source.displayLabel} • fictional ${source.fictionalLast4}',
          ),
          subtitle: Text(source.demo.limitations.join(' ')),
          trailing: IconButton(
            key: Key('funding-delete-${source.id}'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: 'Delete fictional source',
            onPressed: controller.isMutating ? null : () => onDelete(source.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            key: const Key('funding-add-moon-reserve'),
            style: _controlStyle,
            onPressed: controller.isMutating
                ? null
                : () =>
                      unawaited(controller.create(FundingFixture.moonReserve)),
            child: const Text('Add Moon Reserve'),
          ),
          OutlinedButton(
            key: const Key('funding-add-constellation'),
            style: _controlStyle,
            onPressed: controller.isMutating
                ? null
                : () => unawaited(
                    controller.create(FundingFixture.constellationSavings),
                  ),
            child: const Text('Add Constellation Savings'),
          ),
        ],
      ),
      if (controller.pendingFixture != null)
        _PendingCommandActions(
          text: 'Pending source: ${_fixtureLabel(controller.pendingFixture!)}',
          retryKey: const Key('funding-create-retry'),
          discardKey: const Key('funding-create-discard'),
          onRetry: () => unawaited(controller.retryPendingCreate()),
          onDiscard: controller.discardPendingCreate,
        ),
      if (controller.message case final message?) Text(message),
    ],
  );
}

class _ContributionPanel extends StatelessWidget {
  const _ContributionPanel({
    required this.controller,
    required this.portfolioId,
    required this.sourceId,
    required this.amountController,
  });
  final ContributionController controller;
  final String portfolioId;
  final String? sourceId;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase;
    final receipt = controller.receipt;
    if (receipt != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Authoritative Demo receipt',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Command ${receipt.commandId} · portfolio v${receipt.portfolioVersion}',
          ),
          Text(
            'Ledger transactions: ${receipt.ledgerTransactionIds.join(', ')}',
          ),
          if (phase == ContributionPhase.receiptRefreshPending)
            FilledButton(
              key: const Key('receipt-refresh'),
              style: _controlStyle,
              onPressed: () => unawaited(controller.retryPortfolioRefresh()),
              child: const Text('Refresh portfolio authority'),
            ),
          if (controller.message case final message?) Text(message),
        ],
      );
    }
    if (phase == ContributionPhase.review) {
      final draft = controller.draft!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review contribution',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${MinorMoney.usd(draft.minorUnits)} from the selected fictional source.',
          ),
          const Text('Nothing moves until you confirm.'),
          FilledButton(
            key: const Key('confirm-contribution'),
            style: _controlStyle,
            onPressed: controller.isConfirming
                ? null
                : () => unawaited(controller.confirm()),
            child: const Text('Confirm Demo contribution'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'One-time Demo contribution',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(controller.defaults.label),
        const SizedBox(height: 12),
        TextField(
          key: const Key('contribution-amount'),
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Demo amount (USD)',
            prefixText: r'$ ',
            helperText: 'Editable suggestion; never confirmed automatically.',
          ),
        ),
        const SizedBox(height: 12),
        if (phase == ContributionPhase.reconciliationRequired)
          FilledButton(
            key: const Key('contribution-reconcile'),
            style: _controlStyle,
            onPressed: () => unawaited(controller.retryPendingReconciliation()),
            child: const Text('Refresh saved command authority'),
          )
        else if (phase == ContributionPhase.retryableFailure ||
            phase == ContributionPhase.conflictReview ||
            phase == ContributionPhase.throttled)
          FilledButton(
            key: const Key('contribution-review-retry'),
            style: _controlStyle,
            onPressed: controller.reviewSameContribution,
            child: const Text('Review unchanged command'),
          )
        else
          FilledButton(
            key: const Key('review-contribution'),
            style: _controlStyle,
            onPressed: sourceId == null
                ? null
                : () => unawaited(_prepare(sourceId!)),
            child: const Text('Review contribution'),
          ),
        if (phase == ContributionPhase.confirming)
          const Center(child: CircularProgressIndicator()),
        if (controller.message case final message?) Text(message),
      ],
    );
  }

  Future<void> _prepare(String selectedSource) async {
    final amount = _minorUnits(amountController.text);
    await controller.prepare(
      portfolioId: portfolioId,
      sourceId: selectedSource,
      minorUnits: amount ?? 0,
    );
  }
}

class _PendingCommandActions extends StatelessWidget {
  const _PendingCommandActions({
    required this.text,
    required this.retryKey,
    required this.discardKey,
    required this.onRetry,
    required this.onDiscard,
  });
  final String text;
  final Key retryKey;
  final Key discardKey;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(text),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(
            key: retryKey,
            style: _controlStyle,
            onPressed: onRetry,
            child: const Text('Retry same command'),
          ),
          TextButton(
            key: discardKey,
            style: _controlStyle,
            onPressed: onDiscard,
            child: const Text('Discard'),
          ),
        ],
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label, $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

final ButtonStyle _controlStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
  tapTargetSize: MaterialTapTargetSize.padded,
);

String _fixtureLabel(FundingFixture fixture) => switch (fixture) {
  FundingFixture.moonReserve => 'Moon Reserve',
  FundingFixture.constellationSavings => 'Constellation Savings',
};

int? _minorUnits(String input) {
  final match = RegExp(r'^\s*(\d{1,8})(?:\.(\d{1,2}))?\s*$').firstMatch(input);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final cents = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(cents.isEmpty ? '0' : cents);
}
