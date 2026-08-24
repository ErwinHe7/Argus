import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../coven/presentation/coven_screen.dart';
import '../../coven/application/controller.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../discover/application/controller.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/application/controller.dart';
import '../../ritual/presentation/daily_ritual_screen.dart';
import '../../ritual/application/daily_ritual_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onToggleTheme,
    required this.dailyRitualController,
    required this.discoverController,
    required this.covenController,
    required this.profileController,
  });

  final ValueChanged<Brightness> onToggleTheme;
  final DailyRitualController dailyRitualController;
  final DiscoverController discoverController;
  final CovenController covenController;
  final ProfileController profileController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _select(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DailyRitualScreen(
        controller: widget.dailyRitualController,
        onOpenCoven: () => _select(2),
        onToggleTheme: () => widget.onToggleTheme(Theme.of(context).brightness),
      ),
      DiscoverScreen(controller: widget.discoverController),
      CovenScreen(controller: widget.covenController),
      ProfileScreen(controller: widget.profileController),
    ];

    return Scaffold(
      key: const Key('app-shell-scaffold'),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: _AdaptiveNavigation(
        selectedIndex: _selectedIndex,
        onSelected: _select,
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
