import 'package:flutter/foundation.dart';

import '../../brokerage_connection/domain/model.dart';

@immutable
class BrokerageObservation<T> {
  const BrokerageObservation({
    required this.state,
    required this.value,
    required this.observedAt,
    required this.expiresAt,
    required this.reason,
  });

  final BrokerageResourceState state;
  final T? value;
  final DateTime? observedAt;
  final DateTime? expiresAt;
  final String? reason;

  bool get hasDisplayableValue =>
      value != null &&
      (state == BrokerageResourceState.fresh ||
          state == BrokerageResourceState.stale ||
          state == BrokerageResourceState.partial ||
          state == BrokerageResourceState.rateLimited ||
          state == BrokerageResourceState.offline);
}

@immutable
class BrokerageBalanceView {
  const BrokerageBalanceView({
    required this.currency,
    required this.cash,
    required this.totalEquity,
    this.marketValue,
    this.buyingPower,
  });

  final String currency;
  final String cash;
  final String totalEquity;
  final String? marketValue;
  final String? buyingPower;
}

@immutable
class BrokeragePositionView {
  const BrokeragePositionView({
    required this.instrumentId,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.availableQuantity,
    required this.currency,
    required this.supported,
    this.marketValue,
    this.averageCost,
  });

  final String instrumentId;
  final String symbol;
  final String name;
  final String quantity;
  final String availableQuantity;
  final String currency;
  final bool supported;
  final String? marketValue;
  final String? averageCost;
}

@immutable
class BrokerageRestrictionView {
  const BrokerageRestrictionView({
    required this.code,
    required this.active,
    required this.providerCode,
    this.detail,
  });

  final String code;
  final bool active;
  final String providerCode;
  final String? detail;
}

@immutable
class BrokeragePortfolioSnapshot {
  const BrokeragePortfolioSnapshot({
    required this.accountId,
    required this.balance,
    required this.positions,
    required this.capabilities,
    required this.restrictions,
  });

  final String accountId;
  final BrokerageObservation<BrokerageBalanceView> balance;
  final BrokerageObservation<List<BrokeragePositionView>> positions;
  final BrokerageObservation<List<BrokerageCapabilityView>> capabilities;
  final BrokerageObservation<List<BrokerageRestrictionView>> restrictions;

  bool get mutationsAvailable => mutationsAvailableAt(DateTime.now().toUtc());

  bool mutationsAvailableAt(DateTime now) {
    final checkedAt = now.toUtc();
    if (capabilities.state != BrokerageResourceState.fresh ||
        restrictions.state != BrokerageResourceState.fresh) {
      return false;
    }
    final capabilityExpiry = capabilities.expiresAt;
    final restrictionExpiry = restrictions.expiresAt;
    final capabilityValues = capabilities.value;
    final restrictionValues = restrictions.value;
    if (capabilityExpiry == null ||
        restrictionExpiry == null ||
        !capabilityExpiry.isAfter(checkedAt) ||
        !restrictionExpiry.isAfter(checkedAt) ||
        capabilityValues == null ||
        restrictionValues == null) {
      return false;
    }
    final manualOrders = capabilityValues.any(
      (capability) =>
          capability.kind == BrokerageCapabilityKind.manualOrders &&
          capability.available,
    );
    final restricted = restrictionValues.any(
      (restriction) => restriction.active,
    );
    return manualOrders && !restricted;
  }
}
