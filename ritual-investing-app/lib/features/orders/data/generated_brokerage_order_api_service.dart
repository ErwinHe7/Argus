import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../domain/brokerage_model.dart';
import 'brokerage_repository.dart';

class GeneratedBrokerageOrderApiService implements BrokerageOrderService {
  GeneratedBrokerageOrderApiService(api.RitualInvestingApiClient client)
    : _api = client.getBrokerageOrdersApi();

  final api.BrokerageOrdersApi _api;

  @override
  Future<BrokerageOrderListView> list(
    String accountId, {
    bool refresh = false,
  }) async {
    try {
      final value = (await _api.listWebullOrders(
        accountId: accountId,
        refresh: refresh ? 'true' : null,
      )).data?.data;
      if (value == null || value.accountId != accountId) {
        _invalidContract();
      }
      return BrokerageOrderListView(
        accountId: value.accountId,
        state: _collectionState(value.state),
        orders: List.unmodifiable(value.orders.map(_order)),
        providerObservedAt: value.providerObservedAt?.toUtc(),
        fetchedAt: value.fetchedAt?.toUtc(),
        expiresAt: value.expiresAt?.toUtc(),
      );
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderDetailView> get(String accountId, String orderId) async {
    try {
      final value = (await _api.getWebullOrder(
        accountId: accountId,
        orderId: orderId,
      )).data?.data;
      if (value == null || value.id != orderId) {
        _invalidContract();
      }
      return BrokerageOrderDetailView(
        order: _detailOrder(value),
        providerObservedAt: value.providerObservedAt.toUtc(),
        fetchedAt: value.fetchedAt.toUtc(),
        generation: value.generation,
      );
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderPreviewView> previewPlace(
    String accountId,
    BrokeragePlaceOrderIntent intent,
  ) async {
    try {
      final value = (await _api.previewWebullOrder(
        accountId: accountId,
        placeBrokerageOrderIntent: _placeIntent(intent),
      )).data?.data;
      return _preview(value, accountId: accountId, intent: intent);
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderPreviewView> previewModify(
    String accountId,
    String orderId,
    BrokerageModifyOrderIntent intent,
  ) async {
    try {
      final value = (await _api.previewWebullOrderModification(
        accountId: accountId,
        orderId: orderId,
        modifyBrokerageOrderIntent: api.ModifyBrokerageOrderIntent(
          quantity: intent.quantity,
          limitPrice: intent.limitPrice,
        ),
      )).data?.data;
      return _preview(
        value,
        accountId: accountId,
        modifyIntent: intent,
        targetOrderId: orderId,
      );
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderPreviewView> previewCancel(
    String accountId,
    String orderId,
  ) async {
    try {
      final value = (await _api.previewWebullOrderCancellation(
        accountId: accountId,
        orderId: orderId,
      )).data?.data;
      return _preview(value, accountId: accountId, targetOrderId: orderId);
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderCommandView> confirmPlace({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) async {
    final intent = preview.placeIntent;
    if (intent == null) {
      throw const BrokerageOrderFailure(BrokerageOrderFailureReason.invalid);
    }
    try {
      final value = (await _api.placeWebullOrder(
        accountId: preview.accountId,
        idempotencyKey: idempotencyKey,
        confirmPlaceBrokerageOrder: api.ConfirmPlaceBrokerageOrder(
          confirmed: true,
          previewId: preview.id,
          intent: _placeIntent(intent),
        ),
      )).data?.data;
      return _command(value, accountId: preview.accountId);
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderCommandView> confirmModify({
    required BrokerageOrderPreviewView preview,
    required BrokerageModifyOrderIntent intent,
    required String idempotencyKey,
  }) async {
    final target = preview.targetOrderId;
    if (target == null) {
      throw const BrokerageOrderFailure(BrokerageOrderFailureReason.invalid);
    }
    try {
      final value = (await _api.modifyWebullOrder(
        accountId: preview.accountId,
        orderId: target,
        idempotencyKey: idempotencyKey,
        confirmModifyBrokerageOrder: api.ConfirmModifyBrokerageOrder(
          confirmed: true,
          previewId: preview.id,
          intent: api.ModifyBrokerageOrderIntent(
            quantity: intent.quantity,
            limitPrice: intent.limitPrice,
          ),
        ),
      )).data?.data;
      return _command(value, accountId: preview.accountId);
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderCommandView> confirmCancel({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) async {
    final target = preview.targetOrderId;
    if (target == null) {
      throw const BrokerageOrderFailure(BrokerageOrderFailureReason.invalid);
    }
    try {
      final value = (await _api.cancelWebullOrder(
        accountId: preview.accountId,
        orderId: target,
        idempotencyKey: idempotencyKey,
        confirmCancelBrokerageOrder: api.ConfirmCancelBrokerageOrder(
          confirmed: true,
          previewId: preview.id,
        ),
      )).data?.data;
      return _command(value, accountId: preview.accountId);
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }

  @override
  Future<BrokerageOrderCommandView> getCommand(String commandId) async {
    try {
      final value = (await _api.getWebullOrderCommand(commandId: commandId))
          .data
          ?.data;
      if (value == null || value.id != commandId) {
        _invalidContract();
      }
      return _command(value, accountId: value.accountId);
    } on DioException catch (error) {
      _throwOrderFailure(error);
    }
  }
}

api.PlaceBrokerageOrderIntent _placeIntent(BrokeragePlaceOrderIntent value) =>
    api.PlaceBrokerageOrderIntent(
      instrumentId: value.instrumentId,
      limitPrice: value.limitPrice,
      orderType: switch (value.orderType) {
        BrokerageOrderType.market =>
          api.PlaceBrokerageOrderIntentOrderTypeEnum.market,
        BrokerageOrderType.limit =>
          api.PlaceBrokerageOrderIntentOrderTypeEnum.limit,
      },
      quantity: value.quantity,
      side: switch (value.side) {
        BrokerageOrderSide.buy => api.PlaceBrokerageOrderIntentSideEnum.buy,
        BrokerageOrderSide.sell => api.PlaceBrokerageOrderIntentSideEnum.sell,
      },
      timeInForce: switch (value.timeInForce) {
        BrokerageTimeInForce.day =>
          api.PlaceBrokerageOrderIntentTimeInForceEnum.day,
        BrokerageTimeInForce.gtc => throw const BrokerageOrderFailure(
          BrokerageOrderFailureReason.invalid,
        ),
      },
    );

BrokerageOrderPreviewView _preview(
  api.BrokerageOrderPreview? value, {
  required String accountId,
  BrokeragePlaceOrderIntent? intent,
  BrokerageModifyOrderIntent? modifyIntent,
  String? targetOrderId,
}) {
  if (value == null ||
      value.accountId != accountId ||
      value.targetOrderId != targetOrderId ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(value.reviewedPayloadHash) ||
      (intent != null &&
          value.operation != api.BrokerageOrderPreviewOperationEnum.place) ||
      (modifyIntent != null &&
          value.operation != api.BrokerageOrderPreviewOperationEnum.modify) ||
      (intent == null &&
          modifyIntent == null &&
          value.operation != api.BrokerageOrderPreviewOperationEnum.cancel) ||
      value.operation ==
          api.BrokerageOrderPreviewOperationEnum.unknownDefaultOpenApi) {
    _invalidContract();
  }
  return BrokerageOrderPreviewView(
    id: value.id,
    accountId: value.accountId,
    operation: BrokerageOrderOperation.values.byName(value.operation.value),
    placeIntent: intent,
    modifyIntent: modifyIntent,
    targetOrderId: value.targetOrderId,
    capabilityVersion: value.capabilityVersion,
    restrictionGeneration: value.restrictionGeneration,
    policyVersion: value.policyVersion,
    reviewedPayloadHash: value.reviewedPayloadHash,
    expiresAt: value.expiresAt.toUtc(),
    currency: value.currency,
    estimatedTotal: value.estimatedTotal,
  );
}

BrokerageOrderCommandView _command(
  api.BrokerageOrderCommand? value, {
  required String accountId,
}) {
  if (value == null ||
      value.accountId != accountId ||
      value.operation ==
          api.BrokerageOrderCommandOperationEnum.unknownDefaultOpenApi) {
    _invalidContract();
  }
  return BrokerageOrderCommandView(
    id: value.id,
    accountId: value.accountId,
    operation: BrokerageOrderOperation.values.byName(value.operation.value),
    state: switch (value.state) {
      api.BrokerageOrderCommandStateEnum.dispatching =>
        BrokerageProviderCommandState.dispatching,
      api.BrokerageOrderCommandStateEnum.accepted =>
        BrokerageProviderCommandState.accepted,
      api.BrokerageOrderCommandStateEnum.ambiguous =>
        BrokerageProviderCommandState.ambiguous,
      api.BrokerageOrderCommandStateEnum.reconciling =>
        BrokerageProviderCommandState.reconciling,
      api.BrokerageOrderCommandStateEnum.resolved =>
        BrokerageProviderCommandState.resolved,
      api.BrokerageOrderCommandStateEnum.failed =>
        BrokerageProviderCommandState.failed,
      api.BrokerageOrderCommandStateEnum.manualReview =>
        BrokerageProviderCommandState.manualReview,
      api.BrokerageOrderCommandStateEnum.unknownDefaultOpenApi =>
        BrokerageProviderCommandState.unknown,
    },
    ambiguous: value.ambiguous,
    orderId: value.orderId,
    targetOrderId: value.targetOrderId,
    createdAt: value.createdAt.toUtc(),
    updatedAt: value.updatedAt.toUtc(),
  );
}

BrokerageOrderView _order(api.BrokerageOrder value) => BrokerageOrderView(
  id: value.id,
  instrumentId: value.instrumentId,
  symbol: value.symbol,
  side: switch (value.side) {
    api.BrokerageOrderSideEnum.buy => BrokerageOrderSide.buy,
    api.BrokerageOrderSideEnum.sell => BrokerageOrderSide.sell,
    _ => null,
  },
  orderType: switch (value.orderType) {
    api.BrokerageOrderOrderTypeEnum.market => BrokerageOrderType.market,
    api.BrokerageOrderOrderTypeEnum.limit => BrokerageOrderType.limit,
    _ => null,
  },
  timeInForce: switch (value.timeInForce) {
    api.BrokerageOrderTimeInForceEnum.day => BrokerageTimeInForce.day,
    api.BrokerageOrderTimeInForceEnum.gtc => BrokerageTimeInForce.gtc,
    _ => null,
  },
  quantity: value.quantity,
  filledQuantity: value.filledQuantity,
  state: _orderState(value.state.value),
  terminal: value.terminal,
  currency: value.currency,
  limitPrice: value.limitPrice,
  stopPrice: value.stopPrice,
  averageFillPrice: value.averageFillPrice,
);

BrokerageOrderView _detailOrder(api.BrokerageOrderDetail value) =>
    BrokerageOrderView(
      id: value.id,
      instrumentId: value.instrumentId,
      symbol: value.symbol,
      side: value.side.value == 'buy'
          ? BrokerageOrderSide.buy
          : value.side.value == 'sell'
          ? BrokerageOrderSide.sell
          : null,
      orderType: value.orderType.value == 'market'
          ? BrokerageOrderType.market
          : value.orderType.value == 'limit'
          ? BrokerageOrderType.limit
          : null,
      timeInForce: value.timeInForce.value == 'day'
          ? BrokerageTimeInForce.day
          : value.timeInForce.value == 'gtc'
          ? BrokerageTimeInForce.gtc
          : null,
      quantity: value.quantity,
      filledQuantity: value.filledQuantity,
      state: _orderState(value.state.value),
      terminal: value.terminal,
      currency: value.currency,
      limitPrice: value.limitPrice,
      stopPrice: value.stopPrice,
      averageFillPrice: value.averageFillPrice,
    );

BrokerageProviderOrderState _orderState(String value) => switch (value) {
  'pending' => BrokerageProviderOrderState.pending,
  'partially_filled' => BrokerageProviderOrderState.partiallyFilled,
  'filled' => BrokerageProviderOrderState.filled,
  'cancelled' => BrokerageProviderOrderState.cancelled,
  'rejected' => BrokerageProviderOrderState.rejected,
  'expired' => BrokerageProviderOrderState.expired,
  _ => BrokerageProviderOrderState.unknown,
};

BrokerageOrderCollectionState _collectionState(
  api.BrokerageOrderListStateEnum value,
) => switch (value) {
  api.BrokerageOrderListStateEnum.fresh => BrokerageOrderCollectionState.fresh,
  api.BrokerageOrderListStateEnum.empty => BrokerageOrderCollectionState.empty,
  api.BrokerageOrderListStateEnum.stale => BrokerageOrderCollectionState.stale,
  api.BrokerageOrderListStateEnum.partial =>
    BrokerageOrderCollectionState.partial,
  api.BrokerageOrderListStateEnum.unavailable =>
    BrokerageOrderCollectionState.unavailable,
  api.BrokerageOrderListStateEnum.offline =>
    BrokerageOrderCollectionState.offline,
  api.BrokerageOrderListStateEnum.rateLimited =>
    BrokerageOrderCollectionState.rateLimited,
  api.BrokerageOrderListStateEnum.disconnected =>
    BrokerageOrderCollectionState.disconnected,
  api.BrokerageOrderListStateEnum.reauthorizationRequired =>
    BrokerageOrderCollectionState.reauthorizationRequired,
  api.BrokerageOrderListStateEnum.unknownDefaultOpenApi =>
    BrokerageOrderCollectionState.unknown,
};

Never _throwOrderFailure(DioException error) {
  if (ApiFailureMapper.isTransportFailure(error)) {
    throw const BrokerageOrderFailure(BrokerageOrderFailureReason.offline);
  }
  final code = ApiFailureMapper.errorCode(error.response?.data);
  throw BrokerageOrderFailure(switch (code) {
    'brokerage_authority_stale' ||
    'capability_unavailable' ||
    'brokerage_restricted' => BrokerageOrderFailureReason.staleAuthority,
    'preview_expired' ||
    'preview_replayed' ||
    'preview_mismatch' => BrokerageOrderFailureReason.stalePreview,
    'account_command_blocked' => BrokerageOrderFailureReason.ambiguityBlocked,
    'forbidden' => BrokerageOrderFailureReason.forbidden,
    'rate_limited' => BrokerageOrderFailureReason.throttled,
    'provider_contract_unavailable' ||
    'service_unavailable' => BrokerageOrderFailureReason.unavailable,
    _ => BrokerageOrderFailureReason.invalid,
  });
}

Never _invalidContract() => throw const BrokerageOrderFailure(
  BrokerageOrderFailureReason.invalid,
  message: 'The Webull order response is not supported by this app version.',
);
