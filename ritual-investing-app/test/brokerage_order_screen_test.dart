import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';
import 'package:ritual_investing_app/features/orders/application/brokerage_order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/orders/domain/brokerage_model.dart';
import 'package:ritual_investing_app/features/orders/presentation/brokerage_order_screen.dart';
import 'package:ritual_investing_app/features/portfolio/application/brokerage_controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/brokerage_model.dart';

void main() {
  testWidgets('member reviews and explicitly confirms a Webull command', (
    tester,
  ) async {
    final harness = await _Harness.create(fresh: true);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('webull-order-authority-copy')),
      findsOneWidget,
    );
    expect(find.textContaining('Demo order'), findsNothing);
    expect(find.byKey(const Key('preview-webull-order')), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-webull-order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('webull-order-review')), findsOneWidget);
    expect(find.textContaining('BUY ARG'), findsOneWidget);
    expect(find.text('Capability version 3'), findsOneWidget);
    expect(find.text('Restriction generation 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-webull-order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('webull-command-status')), findsOneWidget);
    expect(find.textContaining('Acknowledged, nonterminal'), findsOneWidget);
    expect(harness.service.confirmCalls, 1);
  });

  testWidgets('stale capability keeps history visible and disables entry', (
    tester,
  ) async {
    final harness = await _Harness.create(fresh: false);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('webull-orders-disabled')), findsOneWidget);
    expect(
      find.textContaining('restriction authority is stale or unavailable'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('preview-webull-order')),
    );
    expect(button.onPressed, isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('refresh-webull-orders')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('No Webull orders are available for this account.'),
      findsOneWidget,
    );
  });

  testWidgets('every provider order state uses non-misleading copy', (
    tester,
  ) async {
    final harness = await _Harness.create(
      fresh: true,
      orderList: [
        _order('pending', BrokerageProviderOrderState.pending),
        _order(
          'partial',
          BrokerageProviderOrderState.partiallyFilled,
          quantity: '2',
          filled: '1',
        ),
        _order('filled', BrokerageProviderOrderState.filled, terminal: true),
        _order(
          'cancelled',
          BrokerageProviderOrderState.cancelled,
          terminal: true,
        ),
        _order(
          'rejected',
          BrokerageProviderOrderState.rejected,
          terminal: true,
        ),
        _order('expired', BrokerageProviderOrderState.expired, terminal: true),
        _order('unknown', BrokerageProviderOrderState.unknown),
      ],
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    for (final copy in [
      'Pending at Webull',
      'Partially filled 1 of 2',
      'Filled at Webull',
      'Cancelled at Webull',
      'Rejected by Webull',
      'Expired at Webull',
      'Unknown provider state · no terminal outcome assumed',
    ]) {
      await tester.scrollUntilVisible(
        find.text(copy),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(copy), findsOneWidget);
    }
  });
}

class _Harness {
  _Harness(this.portfolio, this.orders, this.service);

  final BrokeragePortfolioController portfolio;
  final BrokerageOrderController orders;
  final _OrderService service;

  static Future<_Harness> create({
    required bool fresh,
    List<BrokerageOrderView> orderList = const [],
  }) async {
    final portfolio = BrokeragePortfolioController(
      repository: BrokeragePortfolioRepository(
        service: _PortfolioService(fresh: fresh),
      ),
      initialAccountId: 'account-a',
    );
    await portfolio.open('account-a');
    final service = _OrderService(orderList: orderList);
    final orders = BrokerageOrderController(
      repository: BrokerageOrderRepository(service: service),
      portfolioController: portfolio,
      pendingStore: PendingCommandStore(storage: _Storage()),
      scope: const CacheScope(accountId: 'member-a', resetGeneration: 0),
      createKey: () => 'widget-key',
      now: () => DateTime.utc(2026, 8, 28, 12),
    );
    return _Harness(portfolio, orders, service);
  }

  Widget app() => MaterialApp(
    home: BrokerageOrderScreen(
      accountId: 'account-a',
      controller: orders,
      portfolioController: portfolio,
    ),
  );
}

class _OrderService implements BrokerageOrderService {
  _OrderService({this.orderList = const []});

  final List<BrokerageOrderView> orderList;
  int confirmCalls = 0;

  @override
  Future<BrokerageOrderListView> list(
    String accountId, {
    bool refresh = false,
  }) async => BrokerageOrderListView(
    accountId: accountId,
    state: orderList.isEmpty
        ? BrokerageOrderCollectionState.empty
        : BrokerageOrderCollectionState.fresh,
    orders: orderList,
    providerObservedAt: DateTime.utc(2026, 8, 28, 12),
    fetchedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
  );

  @override
  Future<BrokerageOrderPreviewView> previewPlace(
    String accountId,
    BrokeragePlaceOrderIntent intent,
  ) async => BrokerageOrderPreviewView(
    id: 'preview-a',
    accountId: accountId,
    operation: BrokerageOrderOperation.place,
    placeIntent: intent,
    modifyIntent: null,
    targetOrderId: null,
    capabilityVersion: 3,
    restrictionGeneration: 4,
    policyVersion: 'webull-sandbox-manual-v1',
    reviewedPayloadHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
    currency: 'USD',
    estimatedTotal: '100.00',
  );

  @override
  Future<BrokerageOrderCommandView> confirmPlace({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) async {
    confirmCalls += 1;
    return BrokerageOrderCommandView(
      id: 'command-a',
      accountId: preview.accountId,
      operation: BrokerageOrderOperation.place,
      state: BrokerageProviderCommandState.accepted,
      ambiguous: false,
      orderId: 'order-a',
      targetOrderId: null,
      createdAt: DateTime.utc(2026, 8, 28, 12),
      updatedAt: DateTime.utc(2026, 8, 28, 12),
    );
  }

  @override
  Future<BrokerageOrderCommandView> getCommand(String commandId) =>
      throw UnimplementedError();
  @override
  Future<BrokerageOrderDetailView> get(String accountId, String orderId) =>
      throw UnimplementedError();
  @override
  Future<BrokerageOrderPreviewView> previewCancel(
    String accountId,
    String orderId,
  ) => throw UnimplementedError();
  @override
  Future<BrokerageOrderPreviewView> previewModify(
    String accountId,
    String orderId,
    BrokerageModifyOrderIntent intent,
  ) => throw UnimplementedError();
  @override
  Future<BrokerageOrderCommandView> confirmCancel({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) => throw UnimplementedError();
  @override
  Future<BrokerageOrderCommandView> confirmModify({
    required BrokerageOrderPreviewView preview,
    required BrokerageModifyOrderIntent intent,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

BrokerageOrderView _order(
  String id,
  BrokerageProviderOrderState state, {
  String quantity = '1',
  String filled = '0',
  bool terminal = false,
}) => BrokerageOrderView(
  id: id,
  instrumentId: 'instrument-$id',
  symbol: id.toUpperCase(),
  side: BrokerageOrderSide.buy,
  orderType: BrokerageOrderType.market,
  timeInForce: BrokerageTimeInForce.day,
  quantity: quantity,
  filledQuantity: filled,
  state: state,
  terminal: terminal,
  currency: 'USD',
);

class _PortfolioService implements BrokeragePortfolioService {
  const _PortfolioService({required this.fresh});
  final bool fresh;

  @override
  Future<BrokeragePortfolioSnapshot> fetch(
    String accountId, {
    required bool refresh,
  }) async => BrokeragePortfolioSnapshot(
    accountId: accountId,
    balance: _observation(
      const BrokerageBalanceView(
        currency: 'USD',
        cash: '100',
        totalEquity: '100',
      ),
    ),
    positions: _observation(const [
      BrokeragePositionView(
        instrumentId: 'instrument-a',
        symbol: 'ARG',
        name: 'Argus Synthetic',
        quantity: '1',
        availableQuantity: '1',
        currency: 'USD',
        supported: true,
      ),
    ]),
    capabilities: BrokerageObservation(
      state: fresh
          ? BrokerageResourceState.fresh
          : BrokerageResourceState.stale,
      value: const [
        BrokerageCapabilityView(
          kind: BrokerageCapabilityKind.manualOrders,
          available: true,
          providerCode: 'manual_orders',
        ),
      ],
      observedAt: DateTime.utc(2026, 8, 28, 12),
      expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
      reason: null,
    ),
    restrictions: _observation(const <BrokerageRestrictionView>[]),
  );
}

BrokerageObservation<T> _observation<T>(T value) => BrokerageObservation(
  state: BrokerageResourceState.fresh,
  value: value,
  observedAt: DateTime.utc(2026, 8, 28, 12),
  expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
  reason: null,
);

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
