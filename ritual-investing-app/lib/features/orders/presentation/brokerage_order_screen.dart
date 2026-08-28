import 'dart:async';

import 'package:flutter/material.dart';

import '../../portfolio/application/brokerage_controller.dart';
import '../../portfolio/domain/brokerage_model.dart';
import '../application/brokerage_order_controller.dart';
import '../domain/brokerage_model.dart';

class BrokerageOrderScreen extends StatefulWidget {
  const BrokerageOrderScreen({
    super.key,
    required this.accountId,
    required this.controller,
    required this.portfolioController,
    this.preselectedInstrumentId,
    this.preselectedSymbol,
    this.onOpenOrder,
  });

  final String accountId;
  final BrokerageOrderController controller;
  final BrokeragePortfolioController portfolioController;
  final String? preselectedInstrumentId;
  final String? preselectedSymbol;
  final ValueChanged<String>? onOpenOrder;

  @override
  State<BrokerageOrderScreen> createState() => _BrokerageOrderScreenState();
}

class _BrokerageOrderScreenState extends State<BrokerageOrderScreen> {
  final _quantity = TextEditingController(text: '1');
  final _limit = TextEditingController();
  BrokerageOrderSide _side = BrokerageOrderSide.buy;
  BrokerageOrderType _type = BrokerageOrderType.market;
  String? _instrumentId;

  @override
  void initState() {
    super.initState();
    _instrumentId = widget.preselectedInstrumentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.openAccount(widget.accountId));
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.portfolioController,
    ]),
    builder: (context, _) {
      final positions =
          widget.portfolioController.state.value?.positions.value
              ?.where((position) => position.supported)
              .toList(growable: false) ??
          const <BrokeragePositionView>[];
      final choices = <String, BrokeragePositionView>{
        for (final position in positions) position.instrumentId: position,
      };
      if (widget.preselectedInstrumentId case final id?) {
        choices.putIfAbsent(
          id,
          () => BrokeragePositionView(
            instrumentId: id,
            symbol: widget.preselectedSymbol ?? 'Selected instrument',
            name: 'Selected Webull instrument',
            quantity: '0',
            availableQuantity: '0',
            currency: 'USD',
            supported: true,
          ),
        );
      }
      final selected = choices.containsKey(_instrumentId)
          ? _instrumentId
          : choices.keys.firstOrNull;
      final preview = widget.controller.activePreview;
      final command = widget.controller.command;
      return Scaffold(
        appBar: AppBar(title: const Text('Webull orders')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const Text(
                'Webull owns account authority and order state. Argus sends only the exact manual command you review and confirm.',
                key: Key('webull-order-authority-copy'),
              ),
              const SizedBox(height: 16),
              if (command != null)
                _CommandCard(
                  command: command,
                  phase: widget.controller.phase,
                  onRefresh: widget.controller.refreshCommand,
                ),
              if (preview != null &&
                  (widget.controller.phase == BrokerageOrderPhase.review ||
                      widget.controller.phase ==
                          BrokerageOrderPhase.restoredReview ||
                      widget.controller.phase ==
                          BrokerageOrderPhase.responseUnknown ||
                      widget.controller.phase ==
                          BrokerageOrderPhase.throttled)) ...[
                _ReviewCard(
                  preview: preview,
                  phase: widget.controller.phase,
                  isConfirming: widget.controller.isMutating,
                  onConfirm: widget.controller.confirm,
                  onReviewSaved: widget.controller.reviewRestoredCommand,
                ),
              ] else ...[
                Text(
                  'Create a manual preview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('webull-order-instrument'),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Supported Webull instrument',
                    helperText: 'Only mapped equity and ETF positions appear.',
                  ),
                  items: choices.values
                      .map(
                        (position) => DropdownMenuItem(
                          value: position.instrumentId,
                          child: Text('${position.symbol} · ${position.name}'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.controller.mutationsAvailable
                      ? (value) => setState(() => _instrumentId = value)
                      : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<BrokerageOrderSide>(
                  key: const Key('webull-order-side'),
                  initialValue: _side,
                  decoration: const InputDecoration(labelText: 'Side'),
                  items: BrokerageOrderSide.values
                      .map(
                        (side) => DropdownMenuItem(
                          value: side,
                          child: Text(side.name.toUpperCase()),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.controller.mutationsAvailable
                      ? (value) => setState(() => _side = value ?? _side)
                      : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<BrokerageOrderType>(
                  key: const Key('webull-order-type'),
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Order type'),
                  items: BrokerageOrderType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.controller.mutationsAvailable
                      ? (value) => setState(() => _type = value ?? _type)
                      : null,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('webull-order-quantity'),
                  controller: _quantity,
                  enabled: widget.controller.mutationsAvailable,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    helperText: 'Current Webull policy supports whole shares.',
                  ),
                ),
                if (_type == BrokerageOrderType.limit) ...[
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('webull-order-limit'),
                    controller: _limit,
                    enabled: widget.controller.mutationsAvailable,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Limit price'),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('preview-webull-order'),
                  onPressed:
                      selected == null || !widget.controller.mutationsAvailable
                      ? null
                      : () => unawaited(
                          widget.controller.previewPlace(
                            BrokeragePlaceOrderIntent(
                              instrumentId: selected,
                              symbol: choices[selected]!.symbol,
                              side: _side,
                              orderType: _type,
                              quantity: _quantity.text.trim(),
                              timeInForce: BrokerageTimeInForce.day,
                              limitPrice: _type == BrokerageOrderType.limit
                                  ? _limit.text.trim()
                                  : null,
                            ),
                          ),
                        ),
                  child: const Text('Review Webull order'),
                ),
                if (!widget.controller.mutationsAvailable)
                  Text(
                    widget.controller.authorityGateMessage,
                    key: Key('webull-orders-disabled'),
                  ),
              ],
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(message)),
              ],
              const Divider(height: 40),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Provider order history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('refresh-webull-orders'),
                    tooltip: 'Refresh order history from Webull',
                    onPressed: () => unawaited(
                      widget.controller.refreshOrders(authoritative: true),
                    ),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (widget.controller.orderList?.providerObservedAt
                  case final observed?)
                Text('Observed ${observed.toLocal()}'),
              if (widget.controller.orders.isEmpty)
                const Text('No Webull orders are available for this account.'),
              for (final order in widget.controller.orders)
                ListTile(
                  key: Key('webull-order-${order.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${order.side?.name.toUpperCase() ?? 'UNSUPPORTED'} ${order.symbol}',
                  ),
                  subtitle: Text(_orderStateCopy(order)),
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
}

class BrokerageOrderDetailScreen extends StatefulWidget {
  const BrokerageOrderDetailScreen({
    super.key,
    required this.accountId,
    required this.orderId,
    required this.controller,
  });

  final String accountId;
  final String orderId;
  final BrokerageOrderController controller;

  @override
  State<BrokerageOrderDetailScreen> createState() =>
      _BrokerageOrderDetailScreenState();
}

class _BrokerageOrderDetailScreenState
    extends State<BrokerageOrderDetailScreen> {
  final _quantity = TextEditingController();
  final _limit = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.controller.openAccount(widget.accountId);
      await widget.controller.openOrder(widget.orderId);
      final order = widget.controller.selectedOrder?.order;
      if (order != null && mounted) {
        _quantity.text = order.quantity;
        _limit.text = order.limitPrice ?? '';
      }
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final detail = widget.controller.selectedOrder;
      final order = detail?.order;
      final preview = widget.controller.activePreview;
      return Scaffold(
        appBar: AppBar(title: const Text('Webull order detail')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (order == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(
                  '${order.side?.name.toUpperCase() ?? 'UNSUPPORTED'} ${order.symbol}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  _orderStateCopy(order),
                  key: const Key('webull-order-state'),
                ),
                Text(
                  'Quantity ${order.quantity} · filled ${order.filledQuantity}',
                ),
                if (order.averageFillPrice case final price?)
                  Text('Average fill ${order.currency} $price'),
                if (detail != null)
                  Text(
                    'Provider observed ${detail.providerObservedAt.toLocal()} · fetched ${detail.fetchedAt.toLocal()}',
                  ),
                const SizedBox(height: 20),
                if (preview != null && preview.targetOrderId == order.id)
                  _ReviewCard(
                    preview: preview,
                    phase: widget.controller.phase,
                    isConfirming: widget.controller.isMutating,
                    onConfirm: widget.controller.confirm,
                    onReviewSaved: widget.controller.reviewRestoredCommand,
                  )
                else if (order.canChange) ...[
                  TextField(
                    key: const Key('modify-webull-quantity'),
                    controller: _quantity,
                    enabled: widget.controller.mutationsAvailable,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'New quantity',
                    ),
                  ),
                  if (order.orderType == BrokerageOrderType.limit)
                    TextField(
                      key: const Key('modify-webull-limit'),
                      controller: _limit,
                      enabled: widget.controller.mutationsAvailable,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'New limit price',
                      ),
                    ),
                  FilledButton(
                    key: const Key('preview-webull-modify'),
                    onPressed: widget.controller.mutationsAvailable
                        ? () => unawaited(
                            widget.controller.previewModify(
                              order.id,
                              BrokerageModifyOrderIntent(
                                quantity: _quantity.text.trim(),
                                limitPrice:
                                    order.orderType == BrokerageOrderType.limit
                                    ? _limit.text.trim()
                                    : null,
                              ),
                            ),
                          )
                        : null,
                    child: const Text('Review modification'),
                  ),
                  OutlinedButton(
                    key: const Key('preview-webull-cancel'),
                    onPressed: widget.controller.mutationsAvailable
                        ? () => unawaited(
                            widget.controller.previewCancel(order.id),
                          )
                        : null,
                    child: const Text('Review cancellation'),
                  ),
                  const Text(
                    'A fill can race a modification or cancellation. The later Webull state always wins.',
                  ),
                ],
              ],
              if (widget.controller.command case final command?) ...[
                const SizedBox(height: 16),
                _CommandCard(
                  command: command,
                  phase: widget.controller.phase,
                  onRefresh: widget.controller.refreshCommand,
                ),
              ],
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(message)),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.preview,
    required this.phase,
    required this.isConfirming,
    required this.onConfirm,
    required this.onReviewSaved,
  });

  final BrokerageOrderPreviewView preview;
  final BrokerageOrderPhase phase;
  final bool isConfirming;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onReviewSaved;

  @override
  Widget build(BuildContext context) {
    final intent = preview.placeIntent;
    final modify = preview.modifyIntent;
    final needsReview = phase != BrokerageOrderPhase.review;
    return Card(
      key: const Key('webull-order-review'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review ${preview.operation.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (intent != null) ...[
              Text('${intent.side.name.toUpperCase()} ${intent.symbol}'),
              Text(
                '${intent.quantity} · ${intent.orderType.name} · ${intent.timeInForce.name}',
              ),
              if (intent.limitPrice case final limit?) Text('Limit $limit'),
            ],
            if (modify != null) ...[
              Text('New quantity ${modify.quantity}'),
              if (modify.limitPrice case final limit?) Text('New limit $limit'),
            ],
            if (preview.targetOrderId case final target?) Text('Order $target'),
            if (preview.estimatedTotal case final total?)
              Text('Estimated ${preview.currency ?? ''} $total'),
            Text('Expires ${preview.expiresAt.toLocal()}'),
            Text('Policy ${preview.policyVersion}'),
            Text('Capability version ${preview.capabilityVersion}'),
            Text('Restriction generation ${preview.restrictionGeneration}'),
            const Text(
              'Confirmation is bound to this exact preview. Changed fields require a new preview.',
            ),
            FilledButton(
              key: Key(
                needsReview
                    ? 'review-saved-webull-command'
                    : 'confirm-webull-order',
              ),
              onPressed: isConfirming
                  ? null
                  : needsReview
                  ? () => unawaited(onReviewSaved())
                  : () => unawaited(onConfirm()),
              child: Text(
                needsReview ? 'Review saved command' : 'Confirm with Webull',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.command,
    required this.phase,
    required this.onRefresh,
  });

  final BrokerageOrderCommandView command;
  final BrokerageOrderPhase phase;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('webull-command-status'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Provider command',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${command.operation.name} · ${_commandStateCopy(command.state)}',
          ),
          Text('Updated ${command.updatedAt.toLocal()}'),
          if (command.orderId case final orderId?)
            Text('Webull order $orderId'),
          if (!command.isTerminal)
            OutlinedButton(
              key: const Key('refresh-webull-command'),
              onPressed: () => unawaited(onRefresh()),
              child: const Text('Check command status'),
            ),
        ],
      ),
    ),
  );
}

String _orderStateCopy(BrokerageOrderView order) => switch (order.state) {
  BrokerageProviderOrderState.pending => 'Pending at Webull',
  BrokerageProviderOrderState.partiallyFilled =>
    'Partially filled ${order.filledQuantity} of ${order.quantity}',
  BrokerageProviderOrderState.filled => 'Filled at Webull',
  BrokerageProviderOrderState.cancelled => 'Cancelled at Webull',
  BrokerageProviderOrderState.rejected => 'Rejected by Webull',
  BrokerageProviderOrderState.expired => 'Expired at Webull',
  BrokerageProviderOrderState.unknown =>
    'Unknown provider state · no terminal outcome assumed',
};

String _commandStateCopy(BrokerageProviderCommandState state) =>
    switch (state) {
      BrokerageProviderCommandState.dispatching => 'Dispatching',
      BrokerageProviderCommandState.accepted => 'Acknowledged, nonterminal',
      BrokerageProviderCommandState.ambiguous => 'Ambiguous, account blocked',
      BrokerageProviderCommandState.reconciling =>
        'Reconciling, no resubmission',
      BrokerageProviderCommandState.resolved => 'Resolved',
      BrokerageProviderCommandState.failed => 'Failed',
      BrokerageProviderCommandState.manualReview => 'Manual review required',
      BrokerageProviderCommandState.unknown => 'Unknown, account blocked',
    };
