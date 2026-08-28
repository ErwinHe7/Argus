import 'package:flutter/foundation.dart';

enum BrokerageConnectionPhase {
  disconnected,
  pending,
  connected,
  denied,
  failed,
  temporarilyUnavailable,
  reauthorizationRequired,
  unknown,
}

enum BrokerageAccountAvailability {
  available,
  restricted,
  closed,
  unavailable,
  unknown,
}

enum BrokerageResourceState {
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

enum BrokerageCapabilityKind {
  balancesRead,
  positionsRead,
  ordersRead,
  manualOrders,
  unsupported,
  unknown,
}

@immutable
class BrokerageCapabilityView {
  const BrokerageCapabilityView({
    required this.kind,
    required this.available,
    required this.providerCode,
  });

  final BrokerageCapabilityKind kind;
  final bool available;
  final String providerCode;
}

@immutable
class BrokerageAccountView {
  const BrokerageAccountView({
    required this.id,
    required this.connectionId,
    required this.displayLabel,
    required this.baseCurrency,
    required this.availability,
    required this.resourceState,
    required this.capabilityVersion,
    required this.capabilities,
    required this.selected,
    this.marketTimezone,
    this.observedAt,
    this.expiresAt,
  });

  final String id;
  final String connectionId;
  final String displayLabel;
  final String baseCurrency;
  final BrokerageAccountAvailability availability;
  final BrokerageResourceState resourceState;
  final int capabilityVersion;
  final List<BrokerageCapabilityView> capabilities;
  final bool selected;
  final String? marketTimezone;
  final DateTime? observedAt;
  final DateTime? expiresAt;

  bool get isSelectable =>
      availability == BrokerageAccountAvailability.available;
}

@immutable
class BrokerageConnectionSnapshot {
  const BrokerageConnectionSnapshot({
    required this.phase,
    required this.accounts,
    this.connectionId,
    this.activeAccountId,
    this.lastAuthoritativeObservation,
    this.errorCode,
  });

  const BrokerageConnectionSnapshot.disconnected()
    : phase = BrokerageConnectionPhase.disconnected,
      accounts = const [],
      connectionId = null,
      activeAccountId = null,
      lastAuthoritativeObservation = null,
      errorCode = null;

  final BrokerageConnectionPhase phase;
  final List<BrokerageAccountView> accounts;
  final String? connectionId;
  final String? activeAccountId;
  final DateTime? lastAuthoritativeObservation;
  final String? errorCode;

  bool get isConnected => phase == BrokerageConnectionPhase.connected;
  bool get requiresReauthorization =>
      phase == BrokerageConnectionPhase.reauthorizationRequired;
}

@immutable
class BrokerageAuthorizationSession {
  const BrokerageAuthorizationSession({
    required this.authorizationUri,
    required this.expiresAt,
  });

  final Uri authorizationUri;
  final DateTime expiresAt;
}
