import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../application/admin_session_controller.dart';
import '../domain/admin_models.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.session,
    required this.currentPath,
    required this.child,
    super.key,
  });
  final AdminSessionController session;
  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = adminDestinations
        .where((destination) => session.permits(destination.readPermission))
        .toList(growable: false);
    final selected = visible.indexWhere(
      (destination) => destination.route == currentPath,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: constraints.maxWidth >= 1160 ? 256 : 80,
                      height: visible.length * 64 + 160,
                      child: NavigationRail(
                        selectedIndex: selected < 0 ? null : selected,
                        onDestinationSelected: (index) =>
                            context.go(visible[index].route),
                        extended: constraints.maxWidth >= 1160,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Icon(Icons.brightness_4_outlined),
                        ),
                        trailing: IconButton(
                          tooltip: 'Sign out',
                          onPressed: session.logout,
                          icon: const Icon(Icons.logout),
                        ),
                        destinations: [
                          for (final destination in visible)
                            NavigationRailDestination(
                              icon: Icon(_icon(destination.kind)),
                              label: Text(destination.title),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ritual staff'),
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: Scaffold.of(context).openDrawer,
                icon: const Icon(Icons.menu),
              ),
            ),
          ),
          drawer: NavigationDrawer(
            selectedIndex: selected < 0 ? null : selected,
            onDestinationSelected: (index) {
              Navigator.pop(context);
              context.go(visible[index].route);
            },
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 24, 16, 8),
                child: Text('Workspaces'),
              ),
              for (final destination in visible)
                NavigationDrawerDestination(
                  icon: Icon(_icon(destination.kind)),
                  label: Text(destination.title),
                ),
            ],
          ),
          body: child,
        );
      },
    );
  }

  IconData _icon(AdminWorkspaceKind kind) => switch (kind) {
    AdminWorkspaceKind.editorial => Icons.edit_note,
    AdminWorkspaceKind.catalog => Icons.menu_book_outlined,
    AdminWorkspaceKind.verification => Icons.verified_outlined,
    AdminWorkspaceKind.operations => Icons.admin_panel_settings_outlined,
  };
}
