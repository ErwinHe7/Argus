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
          (MemberRoutes.starpath.path, 'Starpath'),
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

          if (route.$1 == MemberRoutes.starpath.path) {
            expect(
              find.byKey(const Key('starpath-universe-selector')),
              findsOneWidget,
            );
            expect(find.text('Investment'), findsOneWidget);
            expect(find.text('Trading'), findsOneWidget);
            for (var ordinal = 1; ordinal <= 4; ordinal += 1) {
              expect(
                find.byKey(Key('investment-constellation-$ordinal')),
                findsOneWidget,
              );
            }
            expect(
              find.byKey(const Key('investment-constellation-5')),
              findsNothing,
            );

            await tester.tap(find.text('Trading'));
            await tester.pumpAndSettle();
            for (var ordinal = 1; ordinal <= 4; ordinal += 1) {
              expect(
                find.byKey(Key('trading-constellation-$ordinal')),
                findsOneWidget,
              );
            }
            expect(
              find.byKey(const Key('trading-constellation-5')),
              findsNothing,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '2x layout overflow on the Trading universe',
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );

            await tester.tap(find.text('Investment'));
            await tester.pumpAndSettle();
          }
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
