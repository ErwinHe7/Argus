import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';
import 'package:ritual_investing_app/features/orders/application/brokerage_order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/orders/domain/brokerage_model.dart';
import 'package:ritual_investing_app/features/portfolio/application/brokerage_controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/brokerage_repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/brokerage_model.dart';

void main() {
  test(
    'duplicate taps produce one confirmation and one stable local key',
    () async {
      final service = _OrderService()..confirmGate = Completer<void>();
      final controller = await _controller(service);
      expect(await controller.previewPlace(_intent), isTrue);

      final first = controller.confirm();
      final second = controller.confirm();
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, second), isTrue);
      expect(service.confirmCalls, 1);
      expect(service.keys, ['stable-key']);

      service.confirmGate!.complete();
      await first;
      expect(controller.phase, BrokerageOrderPhase.commandAccepted);
    },
  );

  test(
    'lost response never retries until exact saved review is explicit',
    () async {
      final storage = _Storage();
      final firstService = _OrderService()
        ..confirmFailure = const BrokerageOrderFailure(
          BrokerageOrderFailureReason.offline,
        );
      final first = await _controller(firstService, storage: storage);
      await first.previewPlace(_intent);
      await first.confirm();

      expect(firstService.confirmCalls, 1);
      expect(first.phase, BrokerageOrderPhase.responseUnknown);

      final recoveredService = _OrderService();
      final recovered = await _controller(
        recoveredService,
        storage: storage,
        open: false,
      );
      await recovered.openAccount('account-a');

      expect(recovered.phase, BrokerageOrderPhase.restoredReview);
      expect(recoveredService.confirmCalls, 0);
      await recovered.reviewRestoredCommand();
      expect(recoveredService.confirmCalls, 0);
      await recovered.confirm();
      expect(recoveredService.confirmCalls, 1);
      expect(recoveredService.keys, ['stable-key']);
    },
  );

  test(
    'ambiguous command blocks account mutations until server resolution',
    () async {
      final service = _OrderService()
        ..command = _command(
          state: BrokerageProviderCommandState.ambiguous,
          ambiguous: true,
        );
      final controller = await _controller(service);
      await controller.previewPlace(_intent);
      await controller.confirm();

      expect(controller.phase, BrokerageOrderPhase.commandAmbiguous);
      expect(await controller.previewPlace(_intent), isFalse);
      expect(service.previewCalls, 1);

      service.command = _command(
        state: BrokerageProviderCommandState.resolved,
        ambiguous: false,
      );
      await controller.refreshCommand();

      expect(controller.phase, BrokerageOrderPhase.commandResolved);
      expect(await controller.previewPlace(_intent), isTrue);
      expect(service.previewCalls, 2);
    },
  );

  test('stale account authority disables every order mutation', () async {
    final service = _OrderService();
    final controller = await _controller(service, freshAuthority: false);

    expect(controller.mutationsAvailable, isFalse);
    expect(await controller.previewPlace(_intent), isFalse);
    expect(controller.phase, BrokerageOrderPhase.authorityBlocked);
    expect(service.previewCalls, 0);
  });

  test('malformed reviewed payload hash is never journaled', () async {
    final storage = _Storage();
    final service = _OrderService()..reviewedPayloadHash = 'not-a-sha256';
    final controller = await _controller(service, storage: storage);

    expect(await controller.previewPlace(_intent), isFalse);
    expect(controller.activePreview, isNull);
    expect(storage.values, isEmpty);
  });

  test(
    'order numeric bounds match the server canonical decimal contract',
    () async {
      final service = _OrderService();
      final controller = await _controller(service);
      final maximum = BrokeragePlaceOrderIntent(
        instrumentId: 'instrument-a',
        symbol: 'ARG',
        side: BrokerageOrderSide.buy,
        orderType: BrokerageOrderType.limit,
        quantity: '12345678901234567890123456789012345678',
        timeInForce: BrokerageTimeInForce.day,
        limitPrice: '12345678901234567890123456789012345678.123456789012345678',
      );

      expect(await controller.previewPlace(maximum), isTrue);
      expect(service.previewCalls, 1);

      final tooManyQuantityDigits = BrokeragePlaceOrderIntent(
        instrumentId: maximum.instrumentId,
        symbol: maximum.symbol,
        side: maximum.side,
        orderType: maximum.orderType,
        quantity: '${maximum.quantity}9',
        timeInForce: maximum.timeInForce,
        limitPrice: maximum.limitPrice,
      );
      expect(await controller.previewPlace(tooManyQuantityDigits), isFalse);
      expect(service.previewCalls, 1);

      final tooManyPriceFractionDigits = BrokeragePlaceOrderIntent(
        instrumentId: maximum.instrumentId,
        symbol: maximum.symbol,
        side: maximum.side,
        orderType: maximum.orderType,
        quantity: '1',
        timeInForce: maximum.timeInForce,
        limitPrice: '1.1234567890123456789',
      );
      expect(
        await controller.previewPlace(tooManyPriceFractionDigits),
        isFalse,
      );
      expect(service.previewCalls, 1);
    },
  );

  for (final outcome in <BrokerageProviderCommandState, BrokerageOrderPhase>{
    BrokerageProviderCommandState.resolved: BrokerageOrderPhase.commandResolved,
    BrokerageProviderCommandState.failed: BrokerageOrderPhase.commandFailed,
    BrokerageProviderCommandState.manualReview:
        BrokerageOrderPhase.commandManualReview,
  }.entries) {
    test(
      '${outcome.key.name} survives the authoritative list refresh',
      () async {
        final service = _OrderService()
          ..command = _command(
            state: outcome.key,
            ambiguous:
                outcome.key == BrokerageProviderCommandState.manualReview,
          );
        final controller = await _controller(service);
        await controller.previewPlace(_intent);
        await controller.confirm();

        expect(controller.phase, outcome.value);
        expect(controller.message, isNotEmpty);
      },
    );
  }
}

Future<BrokerageOrderController> _controller(
  _OrderService service, {
  _Storage? storage,
  bool freshAuthority = true,
  bool open = true,
}) async {
  final portfolio = BrokeragePortfolioController(
    repository: BrokeragePortfolioRepository(
      service: _PortfolioService(fresh: freshAuthority),
    ),
    initialAccountId: 'account-a',
  );
  await portfolio.open('account-a');
  final controller = BrokerageOrderController(
    repository: BrokerageOrderRepository(service: service),
    portfolioController: portfolio,
    pendingStore: PendingCommandStore(storage: storage ?? _Storage()),
    scope: const CacheScope(accountId: 'member-a', resetGeneration: 0),
    createKey: () => 'stable-key',
    now: () => DateTime.utc(2026, 8, 28, 12),
  );
  if (open) await controller.openAccount('account-a');
  return controller;
}

const _intent = BrokeragePlaceOrderIntent(
  instrumentId: 'instrument-a',
  symbol: 'ARG',
  side: BrokerageOrderSide.buy,
  orderType: BrokerageOrderType.market,
  quantity: '1',
  timeInForce: BrokerageTimeInForce.day,
);

class _OrderService implements BrokerageOrderService {
  int previewCalls = 0;
  int confirmCalls = 0;
  Completer<void>? confirmGate;
  BrokerageOrderFailure? confirmFailure;
  List<String> keys = [];
  String reviewedPayloadHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  BrokerageOrderCommandView command = _command(
    state: BrokerageProviderCommandState.accepted,
    ambiguous: false,
  );

  @override
  Future<BrokerageOrderListView> list(
    String accountId, {
    bool refresh = false,
  }) async => BrokerageOrderListView(
    accountId: accountId,
    state: BrokerageOrderCollectionState.empty,
    orders: const [],
    providerObservedAt: DateTime.utc(2026, 8, 28, 12),
    fetchedAt: DateTime.utc(2026, 8, 28, 12),
    expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
  );

  @override
  Future<BrokerageOrderPreviewView> previewPlace(
    String accountId,
    BrokeragePlaceOrderIntent intent,
  ) async {
    previewCalls += 1;
    return BrokerageOrderPreviewView(
      id: 'preview-a',
      accountId: accountId,
      operation: BrokerageOrderOperation.place,
      placeIntent: intent,
      modifyIntent: null,
      targetOrderId: null,
      capabilityVersion: 3,
      restrictionGeneration: 4,
      policyVersion: 'webull-sandbox-manual-v1',
      reviewedPayloadHash: reviewedPayloadHash,
      expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
      currency: 'USD',
      estimatedTotal: '125.00',
    );
  }

  @override
  Future<BrokerageOrderCommandView> confirmPlace({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) async {
    confirmCalls += 1;
    keys.add(idempotencyKey);
    await confirmGate?.future;
    if (confirmFailure case final failure?) throw failure;
    return command;
  }

  @override
  Future<BrokerageOrderCommandView> getCommand(String commandId) async =>
      command;

  @override
  Future<BrokerageOrderDetailView> get(String accountId, String orderId) =>
      Future.value(
        BrokerageOrderDetailView(
          order: BrokerageOrderView(
            id: orderId,
            instrumentId: 'instrument-a',
            symbol: 'ARG',
            side: BrokerageOrderSide.buy,
            orderType: BrokerageOrderType.market,
            timeInForce: BrokerageTimeInForce.day,
            quantity: '1',
            filledQuantity: '1',
            state: BrokerageProviderOrderState.filled,
            terminal: true,
            currency: 'USD',
          ),
          providerObservedAt: DateTime.utc(2026, 8, 28, 12),
          fetchedAt: DateTime.utc(2026, 8, 28, 12),
          generation: 2,
        ),
      );
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

BrokerageOrderCommandView _command({
  required BrokerageProviderCommandState state,
  required bool ambiguous,
}) => BrokerageOrderCommandView(
  id: 'command-a',
  accountId: 'account-a',
  operation: BrokerageOrderOperation.place,
  state: state,
  ambiguous: ambiguous,
  orderId: state == BrokerageProviderCommandState.resolved ? 'order-a' : null,
  targetOrderId: null,
  createdAt: DateTime.utc(2026, 8, 28, 12),
  updatedAt: DateTime.utc(2026, 8, 28, 12),
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
    balance: BrokerageObservation(
      state: BrokerageResourceState.fresh,
      value: const BrokerageBalanceView(
        currency: 'USD',
        cash: '100',
        totalEquity: '100',
      ),
      observedAt: DateTime.utc(2026, 8, 28, 12),
      expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
      reason: null,
    ),
    positions: BrokerageObservation(
      state: BrokerageResourceState.fresh,
      value: const [],
      observedAt: DateTime.utc(2026, 8, 28, 12),
      expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
      reason: null,
    ),
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
    restrictions: BrokerageObservation(
      state: BrokerageResourceState.fresh,
      value: const [],
      observedAt: DateTime.utc(2026, 8, 28, 12),
      expiresAt: DateTime.utc(2026, 8, 28, 12, 5),
      reason: null,
    ),
  );
}

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
