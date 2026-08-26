import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import '../integration_test/support/member_test_app.dart';

void main() {
  testWidgets('local generated Dio bootstrap drives the real root entry', (
    tester,
  ) async {
    late MemberTestHarness harness;
    await tester.runAsync(() async {
      harness = await MemberTestHarness.start();
      await HttpOverrides.runWithHttpOverrides(
        harness.container.bootstrap,
        _LoopbackHttpOverrides(),
      );
    });
    addTearDown(harness.close);

    expect(harness.lastAuthorization, harness.expectedAuthorization);
    expect(harness.container.memberBootstrap?.accountId, harness.accountId);
    expect(harness.container.memberBootstrap?.onboarding.nextStep, 'welcome');
    expect(
      harness.container.memberBootstrap!.onboarding.version,
      greaterThan(0),
    );

    await tester.pumpWidget(
      RitualInvestingApp(container: harness.container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete onboarding to continue.'), findsOneWidget);
    expect(find.byKey(const Key('app-shell-scaffold')), findsNothing);
  });
}

class _LoopbackHttpOverrides extends HttpOverrides {}
