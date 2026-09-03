enum MemberCapability {
  ritual,
  discover,
  coven,
  you,
  community,
  identity,
  privacy,
  memberScenarios,
  notifications,
  brokerageConnection,
  brokeragePortfolio,
  funding,
  brokerageOrders,
  standaloneDemo,
}

enum MemberCapabilityState { betaBacked, unavailable, standaloneDemoHandoff }

/// Presentation metadata plus independently supplied capability states.
///
/// Public-beta lifecycle status never disables a capability by itself.
class MemberCapabilityPolicy {
  const MemberCapabilityPolicy._({
    required this.isPublicBeta,
    required this._states,
  });

  static const native = MemberCapabilityPolicy._(
    isPublicBeta: false,
    states: <MemberCapability, MemberCapabilityState>{},
  );

  static const publicWebBeta = MemberCapabilityPolicy._(
    isPublicBeta: true,
    states: <MemberCapability, MemberCapabilityState>{
      MemberCapability.ritual: MemberCapabilityState.betaBacked,
      MemberCapability.discover: MemberCapabilityState.betaBacked,
      MemberCapability.coven: MemberCapabilityState.betaBacked,
      MemberCapability.you: MemberCapabilityState.betaBacked,
      MemberCapability.community: MemberCapabilityState.betaBacked,
      MemberCapability.identity: MemberCapabilityState.betaBacked,
      MemberCapability.privacy: MemberCapabilityState.betaBacked,
      MemberCapability.memberScenarios: MemberCapabilityState.betaBacked,
      MemberCapability.notifications: MemberCapabilityState.betaBacked,
      MemberCapability.brokerageConnection: MemberCapabilityState.betaBacked,
      MemberCapability.brokeragePortfolio: MemberCapabilityState.betaBacked,
      MemberCapability.funding: MemberCapabilityState.betaBacked,
      MemberCapability.brokerageOrders: MemberCapabilityState.betaBacked,
      MemberCapability.standaloneDemo:
          MemberCapabilityState.standaloneDemoHandoff,
    },
  );

  final bool isPublicBeta;
  final Map<MemberCapability, MemberCapabilityState> _states;

  MemberCapabilityState stateOf(MemberCapability capability) =>
      _states[capability] ?? MemberCapabilityState.betaBacked;

  bool permits(MemberCapability capability) =>
      stateOf(capability) == MemberCapabilityState.betaBacked;
}
