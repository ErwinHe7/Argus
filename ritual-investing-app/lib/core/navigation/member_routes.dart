import '../bootstrap/app_runtime.dart';
import '../bootstrap/member_bootstrap.dart';

typedef MemberResourceAccess = bool Function(
  MemberRouteDefinition route,
  String stableId,
);

class MemberRouteDefinition {
  const MemberRouteDefinition({
    required this.name,
    required this.path,
    required this.branch,
    this.relativeResourcePath,
  });

  final String name;
  final String path;
  final MemberBranch branch;
  final String? relativeResourcePath;

  bool get isResource => relativeResourcePath != null;

  String location([String? stableId]) {
    if (!isResource) return path;
    if (stableId == null || !MemberRoutes.isStableId(stableId)) {
      throw ArgumentError.value(stableId, 'stableId', 'Invalid stable ID.');
    }
    return '$path/${Uri.encodeComponent(stableId)}';
  }
}

abstract final class MemberRoutes {
  static const youInvestingPath = '/you/investing';
  static const youRitualPreferencesPath = '/you/ritual-preferences';
  static const youAstrologyPath = '/you/astrology';
  static const youPoliciesPath = '/you/policies';
  static const youAccountPath = '/you/account';
  static const discoverSearchPath = '/discover/search';
  static const discoverCirclesPath = '/discover/circles';
  static const ritualBriefingsPath = '/ritual/briefings';
  static const youNotificationsPath = '/you/notifications';
  static const youNotificationPreferencesPath = '/you/notification-preferences';
  static const youPrivacyPath = '/you/privacy';
  static const youIntentionsPath = '/you/intentions';

  static const ritual = MemberRouteDefinition(
    name: 'ritual',
    path: '/ritual',
    branch: MemberBranch.ritual,
  );
  static const discover = MemberRouteDefinition(
    name: 'discover',
    path: '/discover',
    branch: MemberBranch.discover,
  );
  static const starpath = MemberRouteDefinition(
    name: 'starpath',
    path: '/starpath',
    branch: MemberBranch.starpath,
  );
  static const coven = MemberRouteDefinition(
    name: 'coven',
    path: '/coven',
    branch: MemberBranch.coven,
  );
  static const you = MemberRouteDefinition(
    name: 'you',
    path: '/you',
    branch: MemberBranch.you,
  );

  static const ritualReading = MemberRouteDefinition(
    name: 'ritual-reading',
    path: '/ritual/readings',
    relativeResourcePath: 'readings/:stableId',
    branch: MemberBranch.ritual,
  );
  static const discoverAsset = MemberRouteDefinition(
    name: 'discover-asset',
    path: '/discover/assets',
    relativeResourcePath: 'assets/:stableId',
    branch: MemberBranch.discover,
  );
  static const discoverGrimoire = MemberRouteDefinition(
    name: 'discover-grimoire',
    path: '/discover/grimoires',
    relativeResourcePath: 'grimoires/:stableId',
    branch: MemberBranch.discover,
  );
  static const discoverCircleTemplate = MemberRouteDefinition(
    name: 'discover-circle-template',
    path: '/discover/circle-templates',
    relativeResourcePath: 'circle-templates/:stableId',
    branch: MemberBranch.discover,
  );
  static const discoverCreator = MemberRouteDefinition(
    name: 'discover-creator',
    path: '/discover/creators',
    relativeResourcePath: 'creators/:stableId',
    branch: MemberBranch.discover,
  );
  static const discoverCircle = MemberRouteDefinition(
    name: 'discover-private-circle',
    path: discoverCirclesPath,
    relativeResourcePath: 'circles/:stableId',
    branch: MemberBranch.discover,
  );
  static const covenEntry = MemberRouteDefinition(
    name: 'coven-entry',
    path: '/coven/entries',
    relativeResourcePath: 'entries/:stableId',
    branch: MemberBranch.coven,
  );
  static const portfolio = MemberRouteDefinition(
    name: 'portfolio',
    path: '/you/portfolios',
    relativeResourcePath: 'portfolios/:stableId',
    branch: MemberBranch.you,
  );

  static const roots = [ritual, starpath, discover, coven, you];
  static const resources = [
    ritualReading,
    discoverAsset,
    discoverGrimoire,
    discoverCircleTemplate,
    discoverCreator,
    discoverCircle,
    covenEntry,
    portfolio,
  ];

  static MemberRouteDefinition rootFor(MemberBranch branch) =>
      roots.firstWhere((route) => route.branch == branch);

  static bool isStableId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value);

  static bool isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  static String assetLocation(
    String assetId, {
    required String sourceKind,
    String? sourceId,
  }) {
    if (!isUuid(assetId)) {
      throw ArgumentError.value(assetId, 'assetId', 'Invalid asset UUID.');
    }
    final query = <String, String>{'source': sourceKind};
    if (sourceId != null && isUuid(sourceId)) query['source_id'] = sourceId;
    return Uri(
      path: discoverAsset.location(assetId),
      queryParameters: query,
    ).toString();
  }

  static String portfolioOrdersLocation(
    String portfolioId, {
    String? assetId,
    String? symbol,
  }) {
    if (!isStableId(portfolioId)) {
      throw ArgumentError.value(
        portfolioId,
        'portfolioId',
        'Invalid portfolio ID.',
      );
    }
    final query = <String, String>{};
    if (assetId != null && isUuid(assetId)) query['asset_id'] = assetId;
    if (symbol != null && symbol.trim().isNotEmpty) {
      query['symbol'] = symbol.trim();
    }
    return Uri(
      path: '${portfolio.location(portfolioId)}/orders',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String portfolioOrderLocation(String portfolioId, String orderId) {
    if (!isStableId(orderId)) {
      throw ArgumentError.value(orderId, 'orderId', 'Invalid order ID.');
    }
    return '${portfolioOrdersLocation(portfolioId)}/${Uri.encodeComponent(orderId)}';
  }

  static String memberIntentionLocation(String intentionId) {
    if (!isUuid(intentionId)) {
      throw ArgumentError.value(
        intentionId,
        'intentionId',
        'Invalid Intention UUID.',
      );
    }
    return '$youIntentionsPath/${Uri.encodeComponent(intentionId)}';
  }

  static String memberFutureMirrorLocation(String intentionId) =>
      '${memberIntentionLocation(intentionId)}/future-mirror';

  static String memberFutureMirrorRunLocation(
    String intentionId,
    String runId,
  ) {
    if (!isUuid(runId)) {
      throw ArgumentError.value(runId, 'runId', 'Invalid Future Mirror UUID.');
    }
    return '${memberFutureMirrorLocation(intentionId)}/'
        '${Uri.encodeComponent(runId)}';
  }

  static String briefingLocation(String briefingId) {
    if (!isUuid(briefingId)) {
      throw ArgumentError.value(
        briefingId,
        'briefingId',
        'Invalid briefing UUID.',
      );
    }
    return '$ritualBriefingsPath/${Uri.encodeComponent(briefingId)}';
  }
}

class MemberNavigationPolicy {
  MemberNavigationPolicy._({
    required List<MemberBranch> branches,
    required this.isAuthoritative,
    required this.capabilityVersion,
  }) : branches = List.unmodifiable(branches);

  factory MemberNavigationPolicy.fromBootstrap(MemberBootstrap? bootstrap) {
    final capabilities = bootstrap?.branchCapabilities;
    if (bootstrap == null ||
        capabilities == null ||
        !capabilities.isValidAt(bootstrap.serverTime)) {
      return MemberNavigationPolicy._(
        branches: const [MemberBranch.ritual],
        isAuthoritative: false,
        capabilityVersion: 0,
      );
    }
    final enabled = capabilities.enabled;
    final branches = <MemberBranch>[
      for (final mapping in const [
        (MemberBranchCapability.ritual, MemberBranch.ritual),
        (MemberBranchCapability.starpath, MemberBranch.starpath),
        (MemberBranchCapability.discover, MemberBranch.discover),
        (MemberBranchCapability.coven, MemberBranch.coven),
        (MemberBranchCapability.you, MemberBranch.you),
      ])
        if (enabled.contains(mapping.$1)) mapping.$2,
    ];
    if (branches.isEmpty || branches.first != MemberBranch.ritual) {
      return MemberNavigationPolicy._(
        branches: const [MemberBranch.ritual],
        isAuthoritative: false,
        capabilityVersion: 0,
      );
    }
    return MemberNavigationPolicy._(
      branches: branches,
      isAuthoritative: true,
      capabilityVersion: capabilities.capabilityVersion,
    );
  }

  final List<MemberBranch> branches;
  final bool isAuthoritative;
  final int capabilityVersion;

  bool contains(MemberBranch branch) => branches.contains(branch);

  String? redirectFor(String path) {
    final requested = switch (path) {
      final value when value == '/ritual' || value.startsWith('/ritual/') =>
        MemberBranch.ritual,
      final value when value == '/starpath' || value.startsWith('/starpath/') =>
        MemberBranch.starpath,
      final value when value == '/discover' || value.startsWith('/discover/') =>
        MemberBranch.discover,
      final value when value == '/coven' || value.startsWith('/coven/') =>
        MemberBranch.coven,
      final value when value == '/you' || value.startsWith('/you/') =>
        MemberBranch.you,
      _ => null,
    };
    if (requested == null || contains(requested)) return null;
    return contains(MemberBranch.starpath)
        ? MemberRoutes.starpath.path
        : MemberRoutes.ritual.path;
  }
}
