import '../bootstrap/dependency_container.dart';

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

  static const roots = [ritual, discover, coven, you];
  static const resources = [
    ritualReading,
    discoverAsset,
    covenEntry,
    portfolio,
  ];

  static MemberRouteDefinition rootFor(MemberBranch branch) =>
      roots.firstWhere((route) => route.branch == branch);

  static bool isStableId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value);
}
