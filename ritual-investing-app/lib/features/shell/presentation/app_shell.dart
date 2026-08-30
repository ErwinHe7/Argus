import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/bootstrap/app_runtime.dart';
import '../../public_beta/domain/member_capability_policy.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.branches,
    this.capabilityPolicy = MemberCapabilityPolicy.native,
  });

  final StatefulNavigationShell navigationShell;
  final List<MemberBranch> branches;
  final MemberCapabilityPolicy capabilityPolicy;

  @override
  Widget build(BuildContext context) {
    final shell = Scaffold(
      key: const Key('app-shell-scaffold'),
      body: capabilityPolicy.isPublicBeta
          ? Column(
              children: [
                const _PublicBetaDisclosure(),
                Expanded(child: navigationShell),
              ],
            )
          : navigationShell,
      bottomNavigationBar: _AdaptiveNavigation(
        selectedIndex: navigationShell.currentIndex,
        branches: branches,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
    if (!capabilityPolicy.isPublicBeta) return shell;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          key: const Key('public-beta-mobile-envelope'),
          constraints: const BoxConstraints(maxWidth: 480),
          child: shell,
        ),
      ),
    );
  }
}

class _PublicBetaDisclosure extends StatelessWidget {
  const _PublicBetaDisclosure();

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('public-beta-disclosure'),
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Semantics(
          container: true,
          liveRegion: false,
          label: 'Public beta. Supported data comes from the beta API with source and freshness shown in each view. Live brokerage connections, funding, and orders are unavailable.',
          excludeSemantics: true,
          child: Text(
            'PUBLIC BETA · Beta API data shows source and freshness. '
            'Live brokerage, funding, and orders are unavailable.',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class _AdaptiveNavigation extends StatelessWidget {
  const _AdaptiveNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.branches,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<MemberBranch> branches;

  @override
  Widget build(BuildContext context) {
    if (branches.length < 2) return const SizedBox.shrink();
    final colors = context.ritualColors;
    final platform = Theme.of(context).platform;

    if (!kIsWeb && platform == TargetPlatform.iOS) {
      return CupertinoTabBar(
        currentIndex: selectedIndex,
        onTap: onSelected,
        backgroundColor: colors.screen.withValues(alpha: 0.96),
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: colors.faint,
        border: Border(top: BorderSide(color: colors.line)),
        height: 62,
        items: branches.map(_cupertinoItem).toList(growable: false),
      );
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: branches.map(_materialItem).toList(growable: false),
    );
  }

  BottomNavigationBarItem _cupertinoItem(MemberBranch branch) =>
      switch (branch) {
        MemberBranch.ritual => const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.sparkles),
          label: 'Ritual',
        ),
        MemberBranch.starpath => const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.star_circle),
          label: 'Starpath',
        ),
        MemberBranch.discover => const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.compass),
          label: 'Discover',
        ),
        MemberBranch.coven => const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.moon_stars),
          label: 'Coven',
        ),
        MemberBranch.you => const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.person_crop_circle),
          label: 'You',
        ),
      };

  NavigationDestination _materialItem(MemberBranch branch) => switch (branch) {
    MemberBranch.ritual => const NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: 'Ritual',
    ),
    MemberBranch.starpath => const NavigationDestination(
      icon: Icon(Icons.stars_outlined),
      selectedIcon: Icon(Icons.stars),
      label: 'Starpath',
    ),
    MemberBranch.discover => const NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore),
      label: 'Discover',
    ),
    MemberBranch.coven => const NavigationDestination(
      icon: Icon(Icons.nightlight_outlined),
      selectedIcon: Icon(Icons.nightlight),
      label: 'Coven',
    ),
    MemberBranch.you => const NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'You',
    ),
  };
}
