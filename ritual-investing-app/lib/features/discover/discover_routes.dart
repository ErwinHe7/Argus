import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_runtime.dart';
import '../../core/bootstrap/member_bootstrap.dart';
import '../../core/navigation/member_routes.dart';
import '../asset_codex/application/controller.dart';
import '../asset_codex/domain/model.dart';
import '../asset_codex/presentation/asset_codex_screen.dart';
import '../circles/application/controller.dart';
import '../circles/domain/model.dart';
import '../circles/presentation/circle_template_screen.dart';
import '../circles/presentation/private_circle_detail_screen.dart';
import '../circles/presentation/private_circles_screen.dart';
import '../creators/application/controller.dart';
import '../creators/presentation/creator_detail_screen.dart';
import '../grimoires/application/controller.dart';
import '../grimoires/presentation/grimoire_detail_screen.dart';
import '../search/presentation/search_screen.dart';
import 'domain/model.dart';
import 'presentation/discover_screen.dart';

StatefulShellBranch buildDiscoverBranch({
  required AppRuntime container,
  required MemberResourceAccess resourceAccess,
  bool restorationEnabled = true,
}) {
  GoRoute resourceRoute(MemberRouteDefinition definition) => GoRoute(
    path: definition.relativeResourcePath!,
    name: definition.name,
    redirect: (context, state) {
      final stableId = state.pathParameters['stableId'];
      final available = definition == MemberRoutes.discoverAsset
          ? container.hasAssetCodex
          : switch (definition) {
              MemberRoutes.discoverGrimoire => container.hasGrimoires,
              MemberRoutes.discoverCreator => container.hasCreators,
              MemberRoutes.discoverCircleTemplate ||
              MemberRoutes.discoverCircle => container.hasCircles,
              _ => false,
            };
      return stableId != null &&
              MemberRoutes.isUuid(stableId) &&
              (available || resourceAccess(definition, stableId))
          ? null
          : MemberRoutes.discover.path;
    },
    builder: (context, state) {
      final stableId = state.pathParameters['stableId']!;
      if (definition == MemberRoutes.discoverAsset && container.hasAssetCodex) {
        final source = _assetSource(state.uri.queryParameters);
        return _AssetCodexRoute(
          key: ValueKey(
            'asset-codex-$stableId-${source.kind.name}-'
            '${source.resourceId ?? 'none'}',
          ),
          container: container,
          assetId: stableId,
          source: source,
        );
      }
      if (container.hasGrimoires ||
          container.hasCreators ||
          container.hasCircles) {
        return switch (definition) {
          MemberRoutes.discoverGrimoire => _GrimoireRoute(
            key: ValueKey('grimoire-detail-$stableId'),
            container: container,
            grimoireId: stableId,
          ),
          MemberRoutes.discoverCircleTemplate => _CircleTemplateRoute(
            key: ValueKey('circle-template-detail-$stableId'),
            container: container,
            templateId: stableId,
          ),
          MemberRoutes.discoverCreator => _CreatorRoute(
            key: ValueKey('creator-detail-$stableId'),
            container: container,
            creatorId: stableId,
          ),
          MemberRoutes.discoverCircle => _PrivateCircleRoute(
            key: ValueKey('private-circle-detail-$stableId'),
            container: container,
            circleId: stableId,
          ),
          _ => _DiscoverResourceFallback(route: definition),
        };
      }
      return _DiscoverResourceFallback(route: definition);
    },
  );

  final childRoutes = <RouteBase>[
    resourceRoute(MemberRoutes.discoverAsset),
    resourceRoute(MemberRoutes.discoverGrimoire),
    resourceRoute(MemberRoutes.discoverCircleTemplate),
    resourceRoute(MemberRoutes.discoverCreator),
    resourceRoute(MemberRoutes.discoverCircle),
    GoRoute(
      path: 'circles',
      name: 'discover-private-circles',
      redirect: (context, state) =>
          container.hasCircles ? null : MemberRoutes.discover.path,
      builder: (context, state) => _PrivateCirclesRoute(container: container),
    ),
    GoRoute(
      path: 'search',
      redirect: (context, state) => container.optionalSearchController == null
          ? MemberRoutes.discover.path
          : null,
      builder: (context, state) => SearchScreen(
        controller: container.searchController,
        onOpenAsset: (id) =>
            context.push(MemberRoutes.assetLocation(id, sourceKind: 'search')),
      ),
    ),
  ];

  return StatefulShellBranch(
    restorationScopeId: restorationEnabled
        ? '${MemberRoutes.discover.name}-branch'
        : null,
    routes: [
      GoRoute(
        path: MemberRoutes.discover.path,
        name: MemberRoutes.discover.name,
        builder: (context, state) => _DiscoverBranchRoot(container: container),
        routes: childRoutes,
      ),
    ],
  );
}

class _DiscoverBranchRoot extends StatefulWidget {
  const _DiscoverBranchRoot({required this.container});

  final AppRuntime container;

  @override
  State<_DiscoverBranchRoot> createState() => _DiscoverBranchRootState();
}

class _DiscoverBranchRootState extends State<_DiscoverBranchRoot> {
  @override
  void initState() {
    super.initState();
    widget.container.ensureBranchLoaded(MemberBranch.discover);
  }

  @override
  Widget build(BuildContext context) => DiscoverScreen(
    controller: widget.container.discoverController,
    onOpenSearch: widget.container.optionalSearchController == null
        ? null
        : () => context.push(MemberRoutes.discoverSearchPath),
    onOpenItem: (item) => _openDiscoverItem(context, item),
    onOpenCreator: (creator) =>
        context.push(MemberRoutes.discoverCreator.location(creator.id)),
    onOpenPrivateCircles: widget.container.hasCircles
        ? () => context.push(MemberRoutes.discoverCirclesPath)
        : null,
  );
}

void _openDiscoverItem(BuildContext context, DiscoverItemView item) {
  final location = switch (item.kind) {
    DiscoverItemKind.asset => MemberRoutes.assetLocation(
      item.id,
      sourceKind: 'discover',
      sourceId: item.id,
    ),
    DiscoverItemKind.grimoire => MemberRoutes.discoverGrimoire.location(
      item.id,
    ),
    DiscoverItemKind.circleTemplate =>
      MemberRoutes.discoverCircleTemplate.location(item.id),
    DiscoverItemKind.coven => MemberRoutes.covenEntry.location(item.id),
  };
  context.push(location);
}

AssetSourceContext _assetSource(Map<String, String> query) {
  final kind = switch (query['source']) {
    'ritual' => AssetSourceKind.ritual,
    'circle' => AssetSourceKind.circle,
    'discover' => AssetSourceKind.discover,
    'search' => AssetSourceKind.search,
    _ => AssetSourceKind.direct,
  };
  final sourceId = query['source_id'];
  return AssetSourceContext(
    kind: kind,
    resourceId: sourceId != null && MemberRoutes.isUuid(sourceId)
        ? sourceId
        : null,
  );
}

class _AssetCodexRoute extends StatefulWidget {
  const _AssetCodexRoute({
    super.key,
    required this.container,
    required this.assetId,
    required this.source,
  });

  final AppRuntime container;
  final String assetId;
  final AssetSourceContext source;

  @override
  State<_AssetCodexRoute> createState() => _AssetCodexRouteState();
}

class _AssetCodexRouteState extends State<_AssetCodexRoute> {
  late final AssetCodexController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createAssetCodexController(
      assetId: widget.assetId,
      source: widget.source,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AssetCodexScreen(
    controller: _controller,
    rowanController: widget.container.optionalRowanController,
    personalization:
        widget.container.memberBootstrap?.personalization ??
        const MemberPersonalization(),
    searchController: widget.container.optionalSearchController,
  );
}

class _GrimoireRoute extends StatefulWidget {
  const _GrimoireRoute({
    super.key,
    required this.container,
    required this.grimoireId,
  });

  final AppRuntime container;
  final String grimoireId;

  @override
  State<_GrimoireRoute> createState() => _GrimoireRouteState();
}

class _GrimoireRouteState extends State<_GrimoireRoute> {
  late final GrimoireController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createGrimoireController(widget.grimoireId);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GrimoireDetailScreen(
    controller: _controller,
    onOpenAsset: (id) => context.push(
      MemberRoutes.assetLocation(
        id,
        sourceKind: 'discover',
        sourceId: widget.grimoireId,
      ),
    ),
  );
}

class _CircleTemplateRoute extends StatefulWidget {
  const _CircleTemplateRoute({
    super.key,
    required this.container,
    required this.templateId,
  });

  final AppRuntime container;
  final String templateId;

  @override
  State<_CircleTemplateRoute> createState() => _CircleTemplateRouteState();
}

class _CircleTemplateRouteState extends State<_CircleTemplateRoute> {
  late final CircleTemplateController _controller;
  late final CircleListController _copyController;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCircleTemplateController(
      widget.templateId,
    );
    _copyController = widget.container.createCircleListController();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _copyController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await _copyController.copyTemplate(widget.templateId);
    _openCreated();
  }

  Future<void> _retryCopy() async {
    await _copyController.retryPending();
    _openCreated();
  }

  void _openCreated() {
    final created = _copyController.lastCreated;
    if (!mounted ||
        created == null ||
        _copyController.mutationPhase != CircleMutationPhase.committed) {
      return;
    }
    context.push(MemberRoutes.discoverCircle.location(created.id));
  }

  @override
  Widget build(BuildContext context) => CircleTemplateScreen(
    controller: _controller,
    copyController: _copyController,
    onRetryCopy: () => unawaited(_retryCopy()),
    onOpenAsset: (id) => context.push(
      MemberRoutes.assetLocation(
        id,
        sourceKind: 'discover',
        sourceId: widget.templateId,
      ),
    ),
    onOpenCreator: (creator) =>
        context.push(MemberRoutes.discoverCreator.location(creator.id)),
    onCopy: (_) => unawaited(_copy()),
  );
}

class _CreatorRoute extends StatefulWidget {
  const _CreatorRoute({
    super.key,
    required this.container,
    required this.creatorId,
  });

  final AppRuntime container;
  final String creatorId;

  @override
  State<_CreatorRoute> createState() => _CreatorRouteState();
}

class _CreatorRouteState extends State<_CreatorRoute> {
  late final CreatorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCreatorController(widget.creatorId);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CreatorDetailScreen(controller: _controller);
}

class _PrivateCirclesRoute extends StatefulWidget {
  const _PrivateCirclesRoute({required this.container});

  final AppRuntime container;

  @override
  State<_PrivateCirclesRoute> createState() => _PrivateCirclesRouteState();
}

class _PrivateCirclesRouteState extends State<_PrivateCirclesRoute> {
  late final CircleListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCircleListController();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrivateCirclesScreen(
    controller: _controller,
    onOpenCircle: (id) =>
        context.push(MemberRoutes.discoverCircle.location(id)),
  );
}

class _PrivateCircleRoute extends StatefulWidget {
  const _PrivateCircleRoute({
    super.key,
    required this.container,
    required this.circleId,
  });

  final AppRuntime container;
  final String circleId;

  @override
  State<_PrivateCircleRoute> createState() => _PrivateCircleRouteState();
}

class _PrivateCircleRouteState extends State<_PrivateCircleRoute> {
  late final CircleDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.container.createCircleDetailController(
      widget.circleId,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrivateCircleDetailScreen(
    controller: _controller,
    onOpenAsset: (id) => context.push(
      MemberRoutes.assetLocation(
        id,
        sourceKind: 'circle',
        sourceId: widget.circleId,
      ),
    ),
  );
}

class _DiscoverResourceFallback extends StatelessWidget {
  const _DiscoverResourceFallback({required this.route});

  final MemberRouteDefinition route;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Key('detail-${route.name}'),
    appBar: AppBar(title: const Text('Member detail')),
    body: const SafeArea(
      child: Center(child: Text('This saved member detail is ready.')),
    ),
  );
}
