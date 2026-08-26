import 'package:flutter/foundation.dart';

enum DemoPlanCode {
  free('free'),
  premiumDemo('premium_demo');

  const DemoPlanCode(this.wireValue);
  final String wireValue;
}

enum DemoCapability {
  dailyRitual('daily_ritual', 'Daily Ritual'),
  demoPortfolio('demo_portfolio', 'Demo portfolio'),
  futureMirror('future_mirror', 'Future Mirror');

  const DemoCapability(this.code, this.displayName);
  final String code;
  final String displayName;

  static DemoCapability? fromCode(String value) {
    for (final capability in values) {
      if (capability.code == value) return capability;
    }
    return null;
  }
}

enum DemoEntitlementStatus { active, expired, revoked }

enum DemoCheckoutStatus { open, completed, expired, cancelled }

@immutable
class DemoDisclosure {
  const DemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required this.limitations,
  });

  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;

  @override
  bool operator ==(Object other) =>
      other is DemoDisclosure &&
      other.isDemo == isDemo &&
      other.observedAt == observedAt &&
      other.sourceLabel == sourceLabel &&
      listEquals(other.limitations, limitations);

  @override
  int get hashCode =>
      Object.hash(isDemo, observedAt, sourceLabel, Object.hashAll(limitations));
}

@immutable
class DemoPlan {
  const DemoPlan({
    required this.code,
    required this.displayName,
    required this.priceCopy,
    required this.capabilityCodes,
    required this.disclosure,
  });

  final DemoPlanCode code;
  final String displayName;
  final String priceCopy;
  final Set<String> capabilityCodes;
  final DemoDisclosure disclosure;

  bool includes(DemoCapability capability) =>
      capabilityCodes.contains(capability.code);
}

@immutable
class DemoEntitlement {
  const DemoEntitlement({
    required this.id,
    required this.planCode,
    required this.status,
    required this.startsAt,
    required this.version,
    required this.disclosure,
    this.endsAt,
  });

  final String id;
  final DemoPlanCode planCode;
  final DemoEntitlementStatus status;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int version;
  final DemoDisclosure disclosure;
}

@immutable
class DemoCheckout {
  const DemoCheckout({
    required this.id,
    required this.planCode,
    required this.status,
    required this.expiresAt,
    required this.version,
    required this.disclosure,
  });

  final String id;
  final DemoPlanCode planCode;
  final DemoCheckoutStatus status;
  final DateTime expiresAt;
  final int version;
  final DemoDisclosure disclosure;

  bool isOpenAt(DateTime now) =>
      status == DemoCheckoutStatus.open && expiresAt.isAfter(now.toUtc());
}

enum CapabilityGateReason {
  allowed,
  loading,
  staleAuthority,
  inactiveEntitlement,
  unknownCapability,
  unknownPlan,
  capabilityUnavailable,
}

@immutable
class CapabilityGateResult {
  const CapabilityGateResult(this.reason);

  final CapabilityGateReason reason;
  bool get isAllowed => reason == CapabilityGateReason.allowed;

  @override
  bool operator ==(Object other) =>
      other is CapabilityGateResult && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

@immutable
class MembershipReturnContext {
  const MembershipReturnContext({
    required this.capability,
    required this.location,
  });

  final DemoCapability capability;
  final String location;

  Map<String, Object?> toJson() => {
    'capability': capability.code,
    'return_location': location,
  };
}

class AmbiguousEntitlementMutation implements Exception {
  const AmbiguousEntitlementMutation();
}
