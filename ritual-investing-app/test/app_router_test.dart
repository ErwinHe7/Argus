import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets(
    'restored shell has four lazy branches with independent back stacks',
    (tester) async {
      final loads = FeatureLoadTracker();
      await tester.pumpWidget(
        RitualInvestingApp(
          container: fixtureContainer(loadTracker: loads),
          resourceAccess: (_, _) => true,
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );
      final shell = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      expect(shell.branches, hasLength(4));
      expect(shell.restorationScopeId, 'member-shell');
      expect(loads.count(MemberBranch.ritual), 1);
      expect(loads.count(MemberBranch.discover), 0);
      expect(loads.count(MemberBranch.coven), 0);
      expect(loads.count(MemberBranch.you), 0);

      router.push(MemberRoutes.ritualReading.location('ritual-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-ritual-reading')), findsOneWidget);

      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(loads.count(MemberBranch.discover), 1);
      expect(loads.count(MemberBranch.coven), 0);
      router.push(MemberRoutes.discoverAsset.location('asset-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-discover-asset')), findsOneWidget);

      await tester.tap(find.text('Ritual').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-ritual-reading')), findsOneWidget);
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-discover-asset')), findsOneWidget);
    },
  );

  testWidgets(
    'invalid or unauthorized restored resource falls back without leaking id',
    (tester) async {
      await tester.pumpWidget(
        RitualInvestingApp(
          container: fixtureContainer(),
          resourceAccess: (_, id) => id == 'allowed-id',
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );

      router.go(
        MemberRoutes.discoverAsset.location('private-restored-asset-id'),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, MemberRoutes.discover.path);
      expect(find.textContaining('private-restored-asset-id'), findsNothing);
      expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    },
  );
}
