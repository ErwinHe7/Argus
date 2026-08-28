import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/application/brokerage_controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/brokerage_model.dart';

void main() {
  test('switching accounts clears prior values before the next load', () async {
    final service = _PortfolioService();
    final controller = BrokeragePortfolioController(
      repository: BrokeragePortfolioRepository(service: service),
      initialAccountId: 'account-a',
    );
    await controller.open('account-a');
    expect(controller.state.value?.accountId, 'account-a');

    service.gate = Completer<void>();
    final operation = controller.open('account-b');
    await Future<void>.delayed(Duration.zero);

    expect(controller.accountId, 'account-b');
    expect(controller.state.value, isNull);

    service.gate!.complete();
    await operation;
    expect(controller.state.value?.accountId, 'account-b');
  });

  test(
    'failed refresh preserves timestamped provider values as stale UI',
    () async {
      final service = _PortfolioService();
      final controller = BrokeragePortfolioController(
        repository: BrokeragePortfolioRepository(service: service),
        initialAccountId: 'account-a',
      );
      await controller.open('account-a');
      final prior = controller.state.value;
      service.failure = StateError('offline');

      await controller.refresh();

      expect(controller.state.value, same(prior));
      expect(controller.message, contains('Timestamped'));
    },
  );

  test('manual mutations require fresh server capability and restrictions', () {
    final checkedAt = DateTime.utc(2026, 8, 28, 12);
    expect(_snapshot('account-a').mutationsAvailableAt(checkedAt), isTrue);
    expect(
      _snapshot(
        'account-a',
        capabilityState: BrokerageResourceState.stale,
      ).mutationsAvailableAt(checkedAt),
      isFalse,
    );
    expect(
      _snapshot('account-a', restricted: true).mutationsAvailableAt(checkedAt),
      isFalse,
    );
    expect(
      _snapshot(
        'account-a',
        restrictionsMissing: true,
      ).mutationsAvailableAt(checkedAt),
      isFalse,
    );
    expect(
      _snapshot('account-a')
          .mutationsAvailableAt(DateTime.utc(2026, 8, 28, 12, 1)),
      isFalse,
    );
  });

  test('empty and partial projections remain distinct', () {
    final empty = _snapshot(
      'account-a',
      positionsState: BrokerageResourceState.empty,
      positions: const [],
    );
    final partial = _snapshot(
      'account-a',
      positionsState: BrokerageResourceState.partial,
    );

    expect(empty.positions.state, BrokerageResourceState.empty);
    expect(partial.positions.state, BrokerageResourceState.partial);
    expect(partial.positions.hasDisplayableValue, isTrue);
  });
}

class _PortfolioService implements BrokeragePortfolioService {
  Completer<void>? gate;
  Object? failure;

  @override
  Future<BrokeragePortfolioSnapshot> fetch(
    String accountId, {
    required bool refresh,
  }) async {
    await gate?.future;
    if (failure case final error?) throw error;
    return _snapshot(accountId);
  }
}

BrokeragePortfolioSnapshot _snapshot(
  String accountId, {
  BrokerageResourceState capabilityState = BrokerageResourceState.fresh,
  BrokerageResourceState positionsState = BrokerageResourceState.fresh,
  List<BrokeragePositionView>? positions,
  bool restricted = false,
  bool restrictionsMissing = false,
}) => BrokeragePortfolioSnapshot(
  accountId: accountId,
  balance: BrokerageObservation(
    state: BrokerageResourceState.fresh,
    value: const BrokerageBalanceView(
      currency: 'USD',
      cash: '100.00',
      totalEquity: '125.00',
    ),
    observedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
    reason: null,
  ),
  positions: BrokerageObservation(
    state: positionsState,
    value:
        positions ??
        const [
          BrokeragePositionView(
            instrumentId: 'instrument-a',
            symbol: 'ARG',
            name: 'Argus Synthetic',
            quantity: '1',
            availableQuantity: '1',
            currency: 'USD',
            supported: true,
          ),
        ],
    observedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
    reason: null,
  ),
  capabilities: BrokerageObservation(
    state: capabilityState,
    value: const [
      BrokerageCapabilityView(
        kind: BrokerageCapabilityKind.manualOrders,
        available: true,
        providerCode: 'manual_orders',
      ),
    ],
    observedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
    reason: null,
  ),
  restrictions: BrokerageObservation(
    state: BrokerageResourceState.fresh,
    value: restrictionsMissing
        ? null
        : [
            BrokerageRestrictionView(
              code: 'trading_disabled',
              active: restricted,
              providerCode: 'synthetic',
            ),
          ],
    observedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
    reason: null,
  ),
);
