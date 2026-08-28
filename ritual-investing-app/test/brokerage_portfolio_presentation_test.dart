import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/brokerage_connection/application/controller.dart';
import 'package:ritual_investing_app/features/brokerage_connection/data/repository.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/application/brokerage_controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/brokerage_model.dart';
import 'package:ritual_investing_app/features/portfolio/presentation/brokerage_portfolio_screen.dart';

void main() {
  testWidgets(
    'disconnected brokerage surface exposes an accessible connect path',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final connection = BrokerageConnectionController(
        repository: BrokerageConnectionRepository(
          service: _ConnectionService(
            const BrokerageConnectionSnapshot.disconnected(),
          ),
        ),
        openAuthorization: (_) async => true,
      );
      final portfolio = BrokeragePortfolioController(
        repository: BrokeragePortfolioRepository(
          service: _PortfolioService(_snapshot()),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BrokeragePortfolioScreen(
            accountId: 'account-a',
            connectionController: connection,
            portfolioController: portfolio,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Connect Webull'), findsOneWidget);
      expect(
        find.byKey(const Key('brokerage-connection-action')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Connect Webull. Connect an eligible Webull account to view brokerage balances and positions.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'stale provider values stay timestamped and actions stay disabled',
    (tester) async {
      final connected = BrokerageConnectionSnapshot(
        phase: BrokerageConnectionPhase.connected,
        connectionId: 'connection-a',
        activeAccountId: 'account-a',
        accounts: const [
          BrokerageAccountView(
            id: 'account-a',
            connectionId: 'connection-a',
            displayLabel: 'Synthetic Brokerage',
            baseCurrency: 'USD',
            availability: BrokerageAccountAvailability.available,
            resourceState: BrokerageResourceState.fresh,
            capabilityVersion: 1,
            capabilities: [],
            selected: true,
          ),
        ],
      );
      final connection = BrokerageConnectionController(
        repository: BrokerageConnectionRepository(
          service: _ConnectionService(connected),
        ),
        openAuthorization: (_) async => true,
        initial: connected,
      );
      final portfolio = BrokeragePortfolioController(
        repository: BrokeragePortfolioRepository(
          service: _PortfolioService(
            _snapshot(state: BrokerageResourceState.stale),
          ),
        ),
        initialAccountId: 'account-a',
      );
      await portfolio.open('account-a');

      await tester.pumpWidget(
        MaterialApp(
          home: BrokeragePortfolioScreen(
            accountId: 'account-a',
            connectionController: connection,
            portfolioController: portfolio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stale'), findsWidgets);
      expect(find.textContaining('Observed'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const Key('brokerage-mutation-availability')),
        300,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('brokerage-mutation-availability')),
            )
            .data,
        'Order actions are disabled until Webull capabilities and restrictions are fresh.',
      );
    },
  );
}

class _ConnectionService implements BrokerageConnectionService {
  _ConnectionService(this.snapshot);
  final BrokerageConnectionSnapshot snapshot;

  @override
  Future<BrokerageConnectionSnapshot> fetch() async => snapshot;
  @override
  Future<BrokerageAuthorizationSession> reconnect() =>
      throw UnimplementedError();
  @override
  Future<void> redeemCompletion(String completion) async {}
  @override
  Future<void> selectAccount(String accountId) async {}
  @override
  Future<BrokerageAuthorizationSession> start() => throw UnimplementedError();
}

class _PortfolioService implements BrokeragePortfolioService {
  _PortfolioService(this.snapshot);
  final BrokeragePortfolioSnapshot snapshot;
  @override
  Future<BrokeragePortfolioSnapshot> fetch(
    String accountId, {
    required bool refresh,
  }) async => snapshot;
}

BrokeragePortfolioSnapshot _snapshot({
  BrokerageResourceState state = BrokerageResourceState.fresh,
}) => BrokeragePortfolioSnapshot(
  accountId: 'account-a',
  balance: BrokerageObservation(
    state: state,
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
    state: state,
    value: const [],
    observedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
    reason: null,
  ),
  capabilities: BrokerageObservation(
    state: state,
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
    state: state,
    value: const [],
    observedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
    reason: null,
  ),
);
