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

  testWidgets('AI Analysis route uses the fresh Discover snapshot', (
    tester,
  ) async {
    final container = fixtureContainer();
    await tester.pumpWidget(RitualInvestingApp(container: container));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('app-shell-scaffold'))),
    );

    router.go(MemberRoutes.discoverAiAnalysisPath);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, MemberRoutes.discoverAiAnalysisPath);
    expect(find.byKey(const Key('ai-analysis-screen')), findsOneWidget);
    expect(find.byKey(const Key('discover-ai-risk-level')), findsOneWidget);
    expect(find.textContaining('Elevated'), findsWidgets);
    expect(find.textContaining('not a forecast'), findsNothing);

    await tester.tap(find.byKey(const Key('discover-ai-risk-toggle')));
    await tester.pumpAndSettle();

    expect(find.textContaining('not a forecast'), findsWidgets);
  });
}
