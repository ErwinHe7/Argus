import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('app-shell-scaffold'),
      body: navigationShell,
      bottomNavigationBar: _AdaptiveNavigation(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _AdaptiveNavigation extends StatelessWidget {
  const _AdaptiveNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.sparkles),
            label: 'Ritual',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.moon_stars),
            label: 'Coven',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle),
            label: 'You',
          ),
        ],
      );
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'Ritual',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Icon(Icons.nightlight_outlined),
          selectedIcon: Icon(Icons.nightlight),
          label: 'Coven',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'You',
        ),
      ],
    );
  }
}
