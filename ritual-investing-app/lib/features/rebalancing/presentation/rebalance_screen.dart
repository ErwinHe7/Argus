import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../portfolio/application/controller.dart';
import '../../portfolio/domain/model.dart';
import '../application/rebalance_controller.dart';
import '../domain/model.dart';

const _controlStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(48, 48)),
  tapTargetSize: MaterialTapTargetSize.padded,
);

class RebalanceScreen extends StatefulWidget {
  const RebalanceScreen({
    super.key,
    required this.portfolioId,
    required this.controller,
    required this.portfolioController,
  });
  final String portfolioId;
  final RebalanceController controller;
  final PortfolioController portfolioController;
  @override
  State<RebalanceScreen> createState() => _RebalanceScreenState();
}

class _RebalanceScreenState extends State<RebalanceScreen> {
  String? _assetId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_hydrate());
    });
  }

  Future<void> _hydrate() async {
    await Future.wait([
      widget.controller.openPortfolio(widget.portfolioId),
      widget.portfolioController.open(widget.portfolioId),
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
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.portfolioController,
    ]),
    builder: (context, _) {
      final preview = widget.controller.activePreview;
      final receipt = widget.controller.receipt;
      final holdings =
          widget.portfolioController.detailState.value?.holdings ??
          const <PortfolioHolding>[];
      final selectedAsset =
          holdings.any((holding) => holding.assetId == _assetId)
          ? _assetId
          : holdings.firstOrNull?.assetId;
      String label(String assetId) =>
          holdings
              .where((holding) => holding.assetId == assetId)
              .map((holding) => holding.symbol)
              .firstOrNull ??
          'Demo asset';
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rebalance'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: DemoBadge()),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Provider-free Demo · Allocation scenarios use frozen fictional trades. No brokerage or real money is connected.',
              ),
              const SizedBox(height: 20),
              if (receipt != null) ...[
                Text(
                  'Authoritative rebalance receipt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Command ${receipt.commandId} · portfolio v${receipt.portfolioVersion}',
                ),
                if (widget.controller.phase ==
                    RebalancePhase.receiptRefreshPending)
                  FilledButton(
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.retryReceiptRefresh()),
                    child: const Text('Refresh portfolio authority'),
                  ),
              ] else if (preview != null) ...[
                Text(
                  'Review allocation and frozen trades',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final target in preview.targetAllocation)
                  Text(
                    '${label(target.assetId)} · ${(target.targetBps / 100).toStringAsFixed(2)}% target',
                  ),
                for (final trade in preview.trades)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${trade.side.name.toUpperCase()} ${label(trade.assetId)}',
                    ),
                    subtitle: Text('Quantity ${trade.quantityValue}'),
                    trailing: Text(MinorMoney.usd(trade.notionalMinor)),
                  ),
                Text('Expires ${preview.expiresAt.toLocal()}'),
                if (widget.controller.phase == RebalancePhase.review)
                  FilledButton(
                    key: const Key('confirm-rebalance'),
                    style: _controlStyle,
                    onPressed: widget.controller.isConfirming
                        ? null
                        : () => unawaited(widget.controller.confirm()),
                    child: const Text('Confirm Demo rebalance'),
                  )
                else if (widget.controller.phase ==
                        RebalancePhase.restoredReview ||
                    widget.controller.phase ==
                        RebalancePhase.retryableFailure ||
                    widget.controller.phase == RebalancePhase.throttled) ...[
                  FilledButton(
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.reviewRestoredCommit()),
                    child: const Text('Review unchanged saved rebalance'),
                  ),
                  TextButton(
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.discardPendingCommit()),
                    child: const Text('Discard saved confirmation'),
                  ),
                ],
              ] else ...[
                Text(
                  'Target allocation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'This first experience assigns one Demo asset to 100%. Multi-asset previews remain preserved by the API and controller.',
                ),
                KeyedSubtree(
                  key: ValueKey('rebalance-asset-$selectedAsset'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('rebalance-asset-id'),
                    isExpanded: true,
                    initialValue: selectedAsset,
                    decoration: const InputDecoration(
                      labelText: 'Demo asset',
                      helperText:
                          'Chosen from this portfolio’s labeled holdings.',
                    ),
                    items: holdings
                        .map(
                          (holding) => DropdownMenuItem(
                            value: holding.assetId,
                            child: Text(
                              '${holding.symbol} · ${holding.quantityValue} held',
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
                if (holdings.isEmpty)
                  const Text(
                    'No labeled holdings are available for an allocation preview yet.',
                  ),
                FilledButton(
                  key: const Key('preview-rebalance'),
                  style: _controlStyle,
                  onPressed: selectedAsset == null
                      ? null
                      : () => unawaited(
                          widget.controller.preview(
                            portfolioId: widget.portfolioId,
                            allocations: [
                              RebalanceAllocation(
                                assetId: selectedAsset,
                                targetBps: 10000,
                              ),
                            ],
                          ),
                        ),
                  child: const Text('Review rebalance preview'),
                ),
              ],
              if (widget.controller.phase ==
                  RebalancePhase.reconciliationRequired)
                FilledButton(
                  style: _controlStyle,
                  onPressed: () =>
                      unawaited(widget.controller.retryReconciliation()),
                  child: const Text('Refresh authoritative state'),
                ),
              if (widget.controller.message case final message?) Text(message),
            ],
          ),
        ),
      );
    },
  );
}
