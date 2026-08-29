import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets('search route survives asynchronous feature-scope bootstrap', (
    tester,
  ) async {
    final container = fixtureContainer(includeSearch: true);
    await tester.pumpWidget(RitualInvestingApp(container: container));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );

    router.go(MemberRoutes.discoverSearchPath);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, MemberRoutes.discoverSearchPath);
    expect(find.byKey(const Key('codex-search-field')), findsOneWidget);
  });
}
