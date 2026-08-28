import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/state_status.dart';
import '../../../core/api/view_state.dart';
import '../../brokerage_connection/application/controller.dart';
import '../../brokerage_connection/domain/model.dart';
import '../application/brokerage_controller.dart';
import '../domain/brokerage_model.dart';

class BrokeragePortfolioScreen extends StatefulWidget {
  const BrokeragePortfolioScreen({
    super.key,
    required this.accountId,
    required this.connectionController,
    required this.portfolioController,
    this.onOpenAccount,
  });

  final String accountId;
  final BrokerageConnectionController connectionController;
  final BrokeragePortfolioController portfolioController;
  final ValueChanged<String>? onOpenAccount;

  @override
  State<BrokeragePortfolioScreen> createState() =>
      _BrokeragePortfolioScreenState();
}

class _BrokeragePortfolioScreenState extends State<BrokeragePortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_hydrate());
    });
  }

  Future<void> _hydrate() async {
    if (widget.connectionController.snapshot.activeAccountId !=
        widget.accountId) {
      await widget.connectionController.selectAccount(widget.accountId);
    }
    if (widget.connectionController.snapshot.activeAccountId ==
        widget.accountId) {
      await widget.portfolioController.open(widget.accountId);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.connectionController,
      widget.portfolioController,
    ]),
    builder: (context, _) {
      final connection = widget.connectionController.snapshot;
      final snapshot = widget.portfolioController.state.value;
      return Scaffold(
        appBar: AppBar(title: const Text('Webull portfolio')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _ConnectionStatus(
                controller: widget.connectionController,
                snapshot: connection,
              ),
              const SizedBox(height: 16),
              _AccountSelector(
                snapshot: connection,
                onSelected: (accountId) async {
                  await widget.connectionController.selectAccount(accountId);
                  if (widget.connectionController.snapshot.activeAccountId !=
                      accountId) {
                    return;
                  }
                  final navigate = widget.onOpenAccount;
                  if (navigate != null) {
                    navigate(accountId);
                  } else {
                    await widget.portfolioController.open(accountId);
                  }
                },
              ),
              const SizedBox(height: 12),
              StateStatus(
                phase: widget.portfolioController.state.phase,
                onRetry: widget.portfolioController.refresh,
              ),
              if (widget.portfolioController.message case final message?)
                Text(message),
              if (snapshot != null) ...[
                const SizedBox(height: 16),
                _ObservationCard(
                  title: 'Balance',
                  observation: snapshot.balance,
                  child: _balanceBody(snapshot.balance.value),
                ),
                const SizedBox(height: 12),
                _ObservationCard(
                  title: 'Positions',
                  observation: snapshot.positions,
                  child: _positionsBody(snapshot.positions.value),
                ),
                const SizedBox(height: 12),
                _ObservationCard(
                  title: 'Trading availability',
                  observation: snapshot.capabilities,
                  child: Text(
                    snapshot.mutationsAvailable
                        ? 'Fresh Webull capabilities allow manual orders.'
                        : 'Order actions are disabled until Webull capabilities and restrictions are fresh.',
                    key: const Key('brokerage-mutation-availability'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('brokerage-refresh'),
                  onPressed:
                      widget.portfolioController.state.phase == LoadPhase.stale
                      ? null
                      : widget.portfolioController.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh from Webull'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Widget? _balanceBody(BrokerageBalanceView? balance) => balance == null
    ? null
    : Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _Metric(
            label: 'Total equity',
            value: '${balance.currency} ${balance.totalEquity}',
          ),
          _Metric(label: 'Cash', value: '${balance.currency} ${balance.cash}'),
          if (balance.buyingPower case final buyingPower?)
            _Metric(
              label: 'Buying power',
              value: '${balance.currency} $buyingPower',
            ),
        ],
      );

Widget? _positionsBody(List<BrokeragePositionView>? positions) =>
    positions == null
    ? null
    : Column(
        children: positions
            .map(
              (position) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${position.symbol} · ${position.name}'),
                subtitle: Text(
                  '${position.quantity} shares'
                  '${position.supported ? '' : ' · Read-only unsupported asset'}',
                ),
                trailing: position.marketValue == null
                    ? null
                    : Text('${position.currency} ${position.marketValue}'),
              ),
            )
            .toList(growable: false),
      );

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.controller, required this.snapshot});

  final BrokerageConnectionController controller;
  final BrokerageConnectionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final (title, body, action) = switch (snapshot.phase) {
      BrokerageConnectionPhase.connected => (
        'Connected to Webull',
        'Account values below are provider observations, not an Argus ledger.',
        null,
      ),
      BrokerageConnectionPhase.pending => (
        'Webull authorization pending',
        'Finish in the secure browser, then return to Ritual Investing.',
        null,
      ),
      BrokerageConnectionPhase.reauthorizationRequired => (
        'Reconnect Webull',
        'Your Argus account remains available, but brokerage data needs fresh authorization.',
        controller.reconnect,
      ),
      BrokerageConnectionPhase.denied => (
        'Webull connection cancelled',
        'Nothing was attached. You can try again when ready.',
        controller.connect,
      ),
      BrokerageConnectionPhase.failed ||
      BrokerageConnectionPhase.temporarilyUnavailable ||
      BrokerageConnectionPhase.unknown => (
        'Webull is unavailable',
        'Brokerage actions remain disabled. Ritual and discovery are still available.',
        controller.load,
      ),
      BrokerageConnectionPhase.disconnected => (
        'Connect Webull',
        'Connect an eligible Webull account to view brokerage balances and positions.',
        controller.connect,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $body',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body),
              if (controller.message case final message?) ...[
                const SizedBox(height: 8),
                Text(message),
              ],
              if (action != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('brokerage-connection-action'),
                  onPressed: controller.isBusy ? null : action,
                  child: const Text('Continue'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({required this.snapshot, required this.onSelected});

  final BrokerageConnectionSnapshot snapshot;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (snapshot.accounts.isEmpty) {
      return const Text(
        'No eligible Webull accounts are available yet.',
        key: Key('brokerage-no-accounts'),
      );
    }
    return RadioGroup<String>(
      groupValue: snapshot.activeAccountId,
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Webull account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final account in snapshot.accounts)
            RadioListTile<String>(
              key: Key('brokerage-account-${account.id}'),
              value: account.id,
              enabled: account.isSelectable,
              title: Text(account.displayLabel),
              subtitle: Text(
                '${account.baseCurrency} · ${account.availability.name}',
              ),
            ),
        ],
      ),
    );
  }
}

class _ObservationCard<T> extends StatelessWidget {
  const _ObservationCard({
    required this.title,
    required this.observation,
    required this.child,
  });

  final String title;
  final BrokerageObservation<T> observation;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(_stateLabel(observation.state))),
            ],
          ),
          if (observation.observedAt case final observedAt?)
            Text('Observed ${observedAt.toLocal()}'),
          if (observation.reason case final reason?) Text(reason),
          if (child != null && observation.hasDisplayableValue) ...[
            const SizedBox(height: 12),
            child!,
          ] else if (observation.state == BrokerageResourceState.empty) ...[
            const SizedBox(height: 12),
            const Text('Webull reports no values for this account.'),
          ] else ...[
            const SizedBox(height: 12),
            const Text('No authoritative value is available.'),
          ],
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

String _stateLabel(BrokerageResourceState state) => switch (state) {
  BrokerageResourceState.fresh => 'Fresh',
  BrokerageResourceState.empty => 'Empty',
  BrokerageResourceState.stale => 'Stale',
  BrokerageResourceState.partial => 'Partial',
  BrokerageResourceState.offline => 'Offline',
  BrokerageResourceState.rateLimited => 'Rate limited',
  BrokerageResourceState.reauthorizationRequired => 'Reconnect',
  BrokerageResourceState.disconnected => 'Disconnected',
  BrokerageResourceState.unavailable ||
  BrokerageResourceState.unknown => 'Unavailable',
};
