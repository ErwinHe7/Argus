import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/minor_money.dart';
import '../../portfolio/application/controller.dart';
import '../../portfolio/domain/model.dart';
import '../application/order_controller.dart';
import '../domain/model.dart';

const _controlStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(48, 48)),
  tapTargetSize: MaterialTapTargetSize.padded,
);

class OrderScreen extends StatefulWidget {
  const OrderScreen({
    super.key,
    required this.portfolioId,
    required this.controller,
    required this.portfolioController,
    this.preselectedAssetId,
    this.preselectedSymbol,
    this.onOpenOrder,
  });
  final String portfolioId;
  final OrderController controller;
  final PortfolioController portfolioController;
  final String? preselectedAssetId;
  final String? preselectedSymbol;
  final ValueChanged<String>? onOpenOrder;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _amount = TextEditingController(text: '25.00');
  final _quantity = TextEditingController(text: '0.125');
  OrderSide _side = OrderSide.buy;
  bool _quantityMode = false;
  String? _assetId;

  @override
  void initState() {
    super.initState();
    _assetId = widget.preselectedAssetId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Future.wait([
          widget.controller.openPortfolio(widget.portfolioId),
          widget.portfolioController.open(widget.portfolioId),
        ]),
      );
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _quantity.dispose();
    super.dispose();
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
      final assets = <_OrderAssetChoice>[
        if (widget.preselectedAssetId case final id?)
          _OrderAssetChoice(
            id: id,
            symbol: widget.preselectedSymbol?.trim().isNotEmpty == true
                ? widget.preselectedSymbol!.trim()
                : 'Selected Demo asset',
            detail: 'from Asset Codex',
          ),
        for (final holding in holdings)
          if (holding.assetId != widget.preselectedAssetId)
            _OrderAssetChoice(
              id: holding.assetId,
              symbol: holding.symbol,
              detail: '${holding.quantityValue} held',
            ),
      ];
      final selectedAsset = assets.any((asset) => asset.id == _assetId)
          ? _assetId
          : assets.firstOrNull?.id;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fractional orders'),
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
                'Provider-free Demo · Frozen scenario prices only. No brokerage order or real money movement occurs.',
              ),
              const SizedBox(height: 20),
              if (receipt != null) ...[
                Text(
                  'Authoritative Demo receipt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Command ${receipt.commandId} · portfolio v${receipt.portfolioVersion}',
                ),
                Text('Ledger: ${receipt.ledgerTransactionIds.join(', ')}'),
                if (widget.controller.phase ==
                    OrderCommandPhase.receiptRefreshPending)
                  FilledButton(
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.retryReceiptRefresh()),
                    child: const Text('Refresh portfolio authority'),
                  ),
              ] else if (preview != null &&
                  (widget.controller.phase == OrderCommandPhase.review ||
                      widget.controller.phase ==
                          OrderCommandPhase.restoredReview ||
                      widget.controller.phase ==
                          OrderCommandPhase.retryableFailure ||
                      widget.controller.phase ==
                          OrderCommandPhase.throttled)) ...[
                Text(
                  'Review frozen Demo order',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${preview.side.name.toUpperCase()} ${preview.symbol}'),
                Text(
                  'Quantity ${preview.quantityValue} · ${MinorMoney.usd(preview.notionalMinor)}',
                ),
                Text(
                  'Frozen price ${MinorMoney.usd(preview.frozenPriceMinor)}',
                ),
                Text(
                  'Observed ${preview.observedAt.toLocal()} · expires ${preview.expiresAt.toLocal()}',
                ),
                Text(preview.demo.limitations.join(' ')),
                if (widget.controller.phase == OrderCommandPhase.review)
                  FilledButton(
                    key: const Key('confirm-order'),
                    style: _controlStyle,
                    onPressed: widget.controller.isConfirming
                        ? null
                        : () => unawaited(widget.controller.confirm()),
                    child: const Text('Confirm Demo order'),
                  )
                else
                  FilledButton(
                    key: const Key('review-saved-order'),
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.reviewRestoredCommit()),
                    child: const Text('Review unchanged saved order'),
                  ),
                if (widget.controller.phase != OrderCommandPhase.review)
                  TextButton(
                    style: _controlStyle,
                    onPressed: () =>
                        unawaited(widget.controller.discardPendingCommit()),
                    child: const Text('Discard saved confirmation'),
                  ),
              ] else ...[
                Text(
                  'Create a preview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                KeyedSubtree(
                  key: ValueKey('order-asset-$selectedAsset'),
                  child: DropdownButtonFormField<String>(
                    key: const Key('order-asset-id'),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Demo asset',
                      helperText:
                          'Chosen from this portfolio’s labeled holdings.',
                    ),
                    initialValue: selectedAsset,
                    items: assets
                        .map(
                          (asset) => DropdownMenuItem(
                            value: asset.id,
                            child: Text(
                              '${asset.symbol} · ${asset.detail}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: assets.isEmpty
                        ? null
                        : (value) => setState(() => _assetId = value),
                  ),
                ),
                if (assets.isEmpty)
                  const Text(
                    'No labeled asset is available. Choose “Preview Demo order” from an Asset Codex entry.',
                  ),
                DropdownButtonFormField<OrderSide>(
                  initialValue: _side,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Side'),
                  items: OrderSide.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _side = value ?? _side),
                ),
                SwitchListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enter fractional quantity'),
                  subtitle: const Text(
                    'Otherwise enter an editable Demo USD amount.',
                  ),
                  value: _quantityMode,
                  onChanged: (value) => setState(() => _quantityMode = value),
                ),
                TextField(
                  key: Key(_quantityMode ? 'order-quantity' : 'order-notional'),
                  controller: _quantityMode ? _quantity : _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _quantityMode
                        ? 'Fractional quantity'
                        : 'Demo amount (USD)',
                  ),
                ),
                FilledButton(
                  key: const Key('preview-order'),
                  style: _controlStyle,
                  onPressed: selectedAsset == null
                      ? null
                      : () => unawaited(_preview(selectedAsset)),
                  child: const Text('Review order preview'),
                ),
              ],
              if (widget.controller.phase ==
                  OrderCommandPhase.reconciliationRequired)
                FilledButton(
                  style: _controlStyle,
                  onPressed: () =>
                      unawaited(widget.controller.retryReconciliation()),
                  child: const Text('Refresh authoritative state'),
                ),
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 8),
                Text(message),
              ],
              const Divider(height: 40),
              Text(
                'Order history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.controller.orders.isEmpty)
                const Text('No immutable Demo orders yet.'),
              for (final order in widget.controller.orders)
                ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${order.side.name.toUpperCase()} ${order.symbol}',
                  ),
                  subtitle: Text(
                    '${order.status.name} · command ${order.commandId}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onOpenOrder == null
                      ? null
                      : () => widget.onOpenOrder!(order.id),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _preview(String asset) async {
    if (_quantityMode) {
      final quantity = _quantity.text.trim();
      final fraction = quantity.contains('.')
          ? quantity.split('.').last.length
          : 0;
      await widget.controller.preview(
        OrderDraft.quantity(
          portfolioId: widget.portfolioId,
          assetId: asset,
          side: _side,
          quantityValue: quantity,
          quantityScale: fraction,
        ),
      );
    } else {
      await widget.controller.preview(
        OrderDraft.notional(
          portfolioId: widget.portfolioId,
          assetId: asset,
          side: _side,
          minorUnits: _minorUnits(_amount.text) ?? 0,
        ),
      );
    }
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.portfolioId,
    required this.orderId,
    required this.controller,
  });
  final String portfolioId;
  final String orderId;
  final OrderController controller;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(() async {
        await widget.controller.openPortfolio(widget.portfolioId);
        await widget.controller.openOrder(widget.orderId);
      }());
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final order = widget.controller.selectedOrder;
      return Scaffold(
        appBar: AppBar(title: const Text('Order receipt')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const DemoBadge(),
              if (order == null)
                const Text('Loading immutable Demo order…')
              else ...[
                Text(
                  '${order.side.name.toUpperCase()} ${order.symbol}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Status ${order.status.name} · command ${order.commandId}',
                ),
                if (order.fill case final fill?) ...[
                  Text(
                    'Filled ${fill.quantityValue} at ${MinorMoney.usd(fill.priceMinor)}',
                  ),
                  Text('Filled at ${fill.filledAt.toLocal()}'),
                ],
                Text(order.demo.limitations.join(' ')),
              ],
              if (widget.controller.message case final message?) Text(message),
            ],
          ),
        ),
      );
    },
  );
}

int? _minorUnits(String input) {
  final match = RegExp(r'^\s*(\d{1,8})(?:\.(\d{1,2}))?\s*$').firstMatch(input);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 100 +
      int.parse((match.group(2) ?? '').padRight(2, '0'));
}

class _OrderAssetChoice {
  const _OrderAssetChoice({
    required this.id,
    required this.symbol,
    required this.detail,
  });
  final String id;
  final String symbol;
  final String detail;
}
