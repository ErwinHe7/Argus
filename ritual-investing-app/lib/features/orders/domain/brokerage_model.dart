import 'package:flutter/foundation.dart';

enum BrokerageOrderSide { buy, sell }

enum BrokerageOrderType { market, limit }

enum BrokerageTimeInForce { day, gtc }

enum BrokerageOrderOperation { place, modify, cancel }

enum BrokerageProviderOrderState {
  pending,
  partiallyFilled,
  filled,
  cancelled,
  rejected,
  expired,
  unknown,
}

enum BrokerageProviderCommandState {
  dispatching,
  accepted,
  ambiguous,
  reconciling,
  resolved,
  failed,
  manualReview,
  unknown,
}

enum BrokerageOrderCollectionState {
  fresh,
  empty,
  stale,
  partial,
  unavailable,
  offline,
  rateLimited,
  disconnected,
  reauthorizationRequired,
  unknown,
}

@immutable
class BrokeragePlaceOrderIntent {
  const BrokeragePlaceOrderIntent({
    required this.instrumentId,
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.quantity,
    required this.timeInForce,
    this.limitPrice,
  });

  final String instrumentId;
  final String symbol;
  final BrokerageOrderSide side;
  final BrokerageOrderType orderType;
  final String quantity;
  final BrokerageTimeInForce timeInForce;
  final String? limitPrice;

  Map<String, Object?> toCanonicalMap() => {
    'instrument_id': instrumentId,
    'symbol': symbol,
    'side': side.name,
    'order_type': orderType.name,
    'quantity': quantity,
    'time_in_force': timeInForce.name,
    'limit_price': limitPrice,
  };

  factory BrokeragePlaceOrderIntent.fromCanonicalMap(
    Map<String, Object?> value,
  ) => BrokeragePlaceOrderIntent(
    instrumentId: _requiredString(value, 'instrument_id'),
    symbol: _requiredString(value, 'symbol'),
    side: BrokerageOrderSide.values.byName(_requiredString(value, 'side')),
    orderType: BrokerageOrderType.values.byName(
      _requiredString(value, 'order_type'),
    ),
    quantity: _requiredWholeQuantity(value, 'quantity'),
    timeInForce: BrokerageTimeInForce.values.byName(
      _requiredString(value, 'time_in_force'),
    ),
    limitPrice: _optionalDecimal(value, 'limit_price'),
  );
}

@immutable
class BrokerageModifyOrderIntent {
  const BrokerageModifyOrderIntent({required this.quantity, this.limitPrice});

  final String quantity;
  final String? limitPrice;

  Map<String, Object?> toCanonicalMap() => {
    'quantity': quantity,
    'limit_price': limitPrice,
  };

  factory BrokerageModifyOrderIntent.fromCanonicalMap(
    Map<String, Object?> value,
  ) => BrokerageModifyOrderIntent(
    quantity: _requiredWholeQuantity(value, 'quantity'),
    limitPrice: _optionalDecimal(value, 'limit_price'),
  );
}

@immutable
class BrokerageOrderPreviewView {
  const BrokerageOrderPreviewView({
    required this.id,
    required this.accountId,
    required this.operation,
    required this.placeIntent,
    required this.modifyIntent,
    required this.targetOrderId,
    required this.capabilityVersion,
    required this.restrictionGeneration,
    required this.policyVersion,
    required this.reviewedPayloadHash,
    required this.expiresAt,
    required this.currency,
    required this.estimatedTotal,
  });

  final String id;
  final String accountId;
  final BrokerageOrderOperation operation;
  final BrokeragePlaceOrderIntent? placeIntent;
  final BrokerageModifyOrderIntent? modifyIntent;
  final String? targetOrderId;
  final int capabilityVersion;
  final int restrictionGeneration;
  final String policyVersion;
  final String reviewedPayloadHash;
  final DateTime expiresAt;
  final String? currency;
  final String? estimatedTotal;

  bool isActiveAt(DateTime now) => expiresAt.isAfter(now.toUtc());

  Map<String, Object?> toProtectedMap() => {
    'schema': 1,
    'id': id,
    'account_id': accountId,
    'operation': operation.name,
    'place_intent': placeIntent?.toCanonicalMap(),
    'modify_intent': modifyIntent?.toCanonicalMap(),
    'target_order_id': targetOrderId,
    'capability_version': capabilityVersion,
    'restriction_generation': restrictionGeneration,
    'policy_version': policyVersion,
    'reviewed_payload_hash': reviewedPayloadHash,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'currency': currency,
    'estimated_total': estimatedTotal,
  };

  factory BrokerageOrderPreviewView.fromProtectedMap(
    Map<String, Object?> value,
  ) {
    if (value['schema'] != 1 ||
        value['capability_version'] is! int ||
        value['restriction_generation'] is! int) {
      throw const FormatException('Invalid protected brokerage preview.');
    }
    final expiresAt = DateTime.tryParse(_requiredString(value, 'expires_at'));
    if (expiresAt == null) {
      throw const FormatException('Invalid protected brokerage preview.');
    }
    return BrokerageOrderPreviewView(
      id: _requiredString(value, 'id'),
      accountId: _requiredString(value, 'account_id'),
      operation: BrokerageOrderOperation.values.byName(
        _requiredString(value, 'operation'),
      ),
      placeIntent: value['place_intent'] == null
          ? null
          : BrokeragePlaceOrderIntent.fromCanonicalMap(
              (value['place_intent']! as Map).cast<String, Object?>(),
            ),
      modifyIntent: value['modify_intent'] == null
          ? null
          : BrokerageModifyOrderIntent.fromCanonicalMap(
              (value['modify_intent']! as Map).cast<String, Object?>(),
            ),
      targetOrderId: _optionalString(value, 'target_order_id'),
      capabilityVersion: value['capability_version']! as int,
      restrictionGeneration: value['restriction_generation']! as int,
      policyVersion: _requiredString(value, 'policy_version'),
      reviewedPayloadHash: _requiredString(value, 'reviewed_payload_hash'),
      expiresAt: expiresAt.toUtc(),
      currency: _optionalString(value, 'currency'),
      estimatedTotal: _optionalDecimal(value, 'estimated_total'),
    );
  }
}

@immutable
class BrokerageOrderCommandView {
  const BrokerageOrderCommandView({
    required this.id,
    required this.accountId,
    required this.operation,
    required this.state,
    required this.ambiguous,
    required this.orderId,
    required this.targetOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final BrokerageOrderOperation operation;
  final BrokerageProviderCommandState state;
  final bool ambiguous;
  final String? orderId;
  final String? targetOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTerminal =>
      state == BrokerageProviderCommandState.resolved ||
      state == BrokerageProviderCommandState.failed ||
      state == BrokerageProviderCommandState.manualReview;
}

@immutable
class BrokerageOrderView {
  const BrokerageOrderView({
    required this.id,
    required this.instrumentId,
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.timeInForce,
    required this.quantity,
    required this.filledQuantity,
    required this.state,
    required this.terminal,
    required this.currency,
    this.limitPrice,
    this.stopPrice,
    this.averageFillPrice,
  });

  final String id;
  final String instrumentId;
  final String symbol;
  final BrokerageOrderSide? side;
  final BrokerageOrderType? orderType;
  final BrokerageTimeInForce? timeInForce;
  final String quantity;
  final String filledQuantity;
  final BrokerageProviderOrderState state;
  final bool terminal;
  final String currency;
  final String? limitPrice;
  final String? stopPrice;
  final String? averageFillPrice;

  bool get canChange =>
      !terminal && state != BrokerageProviderOrderState.unknown;
}

@immutable
class BrokerageOrderDetailView {
  const BrokerageOrderDetailView({
    required this.order,
    required this.providerObservedAt,
    required this.fetchedAt,
    required this.generation,
  });

  final BrokerageOrderView order;
  final DateTime providerObservedAt;
  final DateTime fetchedAt;
  final int generation;
}

@immutable
class BrokerageOrderListView {
  const BrokerageOrderListView({
    required this.accountId,
    required this.state,
    required this.orders,
    required this.providerObservedAt,
    required this.fetchedAt,
    required this.expiresAt,
  });

  final String accountId;
  final BrokerageOrderCollectionState state;
  final List<BrokerageOrderView> orders;
  final DateTime? providerObservedAt;
  final DateTime? fetchedAt;
  final DateTime? expiresAt;

  bool get hasDisplayableOrders =>
      orders.isNotEmpty &&
      (state == BrokerageOrderCollectionState.fresh ||
          state == BrokerageOrderCollectionState.stale ||
          state == BrokerageOrderCollectionState.partial ||
          state == BrokerageOrderCollectionState.offline ||
          state == BrokerageOrderCollectionState.rateLimited);
}

class BrokerageOrderFailure implements Exception {
  const BrokerageOrderFailure(this.reason, {this.message});
  final BrokerageOrderFailureReason reason;
  final String? message;
}

enum BrokerageOrderFailureReason {
  offline,
  staleAuthority,
  stalePreview,
  ambiguityBlocked,
  forbidden,
  throttled,
  unavailable,
  invalid,
}

String _requiredString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw const FormatException('Invalid protected brokerage preview.');
  }
  return field;
}

String? _optionalString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field == null) return null;
  if (field is! String || field.trim().isEmpty) {
    throw const FormatException('Invalid protected brokerage preview.');
  }
  return field;
}

String _requiredWholeQuantity(Map<String, Object?> value, String key) {
  final field = _requiredString(value, key);
  if (!_wholeQuantity.hasMatch(field)) {
    throw const FormatException('Invalid protected brokerage preview.');
  }
  return field;
}

String? _optionalDecimal(Map<String, Object?> value, String key) {
  final field = _optionalString(value, key);
  if (field != null && !_decimal.hasMatch(field)) {
    throw const FormatException('Invalid protected brokerage preview.');
  }
  return field;
}

final _decimal = RegExp(r'^(?:0|[1-9]\d{0,37})(?:\.\d{1,18})?$');
final _wholeQuantity = RegExp(r'^[1-9]\d{0,37}$');
