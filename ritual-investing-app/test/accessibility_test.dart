import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';
import 'package:ritual_investing_app/features/public_beta/domain/member_capability_policy.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets(
    'public web beta shell stays mobile-width and keeps its financial disclosure visible',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RitualInvestingApp(
          container: fixtureContainer(
            capabilityPolicy: MemberCapabilityPolicy.publicWebBeta,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('public-beta-disclosure')), findsOneWidget);
      expect(
        find.textContaining(
          'Live brokerage, funding, and orders are unavailable',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('public-beta-mobile-envelope')))
            .width,
        480,
      );
      expect(find.byKey(const Key('you-brokerage')), findsNothing);
    },
  );

  testWidgets(
    'restored ritual uses explicit accessible entry and 2x immersive reflow',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
          );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review today’s ritual'), findsOneWidget);
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.tap(find.byKey(const Key('daily-ritual-return-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('daily-ritual-immersive')), findsOneWidget);
      expect(
        find.byKey(const Key('daily-ritual-immersive-accessibility-scroll')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('ritual-search')), findsNothing);
      expect(find.byKey(const Key('theme-toggle')), findsNothing);
      expect(find.text('Today’s ritual is complete.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('leonidas-starpath')));
      await tester.pump();
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-starpath')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'major member routes remain semantic and operable at 2x in ${brightness.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(
              accessibleNavigation: true,
              disableAnimations: true,
            );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearAllTestValues);

        await tester.pumpWidget(
          RitualInvestingApp(
            container: fixtureContainer(
              includeU9: true,
              includeU11: true,
              privacyRepository: _AccessibilityPrivacyRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shell = find.byKey(const Key('app-shell-scaffold'));
        expect(shell, findsOneWidget);
        final router = GoRouter.of(tester.element(shell));
        final routes = <(String, String)>[
          (MemberRoutes.ritual.path, 'YOUR DAILY SIGNAL'),
          (MemberRoutes.starpath.path, 'Walk the Stars'),
          (MemberRoutes.discover.path, 'Discover'),
          (MemberRoutes.coven.path, 'Founders’ Coven'),
          (MemberRoutes.you.path, 'You'),
        ];

        for (final route in routes) {
          router.go(route.$1);
          await tester.pumpAndSettle();
          expect(find.text(route.$2), findsWidgets);
          expect(
            tester.takeException(),
            isNull,
            reason: '2x layout overflow on ${route.$1}',
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        }

        for (final route in const <(String, String)>[
          (MemberRoutes.youPrivacyPath, 'Privacy and data'),
        ]) {
          router.go(route.$1);
          await tester.pumpAndSettle();
          expect(find.text(route.$2), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '2x focused-route overflow on ${route.$1}',
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        }

        router.go(MemberRoutes.you.path);
        await tester.pumpAndSettle();
        router.push(MemberRoutes.youInvestingPath);
        await tester.pumpAndSettle();
        expect(find.text('Investing profile'), findsWidgets);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(router.state.uri.path, MemberRoutes.you.path);

        final media = MediaQuery.of(tester.element(shell));
        expect(media.disableAnimations, isTrue);
        expect(media.accessibleNavigation, isTrue);
        expect(media.textScaler.scale(16), 32);
        semantics.dispose();
      },
    );
  }
}

class _AccessibilityPrivacyRepository implements PrivacyRepository {
  @override
  Future<void> clearStaleLocalFiles() async {}

  @override
  Future<String?> restoreExportId() async => null;

  @override
  Future<void> rememberExportId(String requestId) async {}

  @override
  Future<void> forgetExportId(String requestId) async {}

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) =>
      throw UnimplementedError();

  @override
  Future<PrivacyExport> getExport(String requestId) =>
      throw UnimplementedError();

  @override
  Future<PrivateExportDelivery> downloadAndShare(String requestId) =>
      throw UnimplementedError();

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(
    String idempotencyKey,
    String stepUpReceipt,
  ) => throw UnimplementedError();

  @override
  Future<bool> accountInactive() async => false;

  @override
  Future<void> cancelAndClearLocal() async {}
}
