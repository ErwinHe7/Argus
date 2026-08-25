import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import 'support/member_test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generated transport reaches the guarded member root', (
    tester,
  ) async {
    late MemberTestHarness harness;
    await tester.runAsync(() async {
      harness = await MemberTestHarness.start();
      await harness.container.bootstrap();
    });
    addTearDown(harness.close);

    expect(harness.lastAuthorization, 'Bearer local-member-access-token');
    await tester.pumpWidget(
      RitualInvestingApp(container: harness.container, bootstrapOnStart: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete onboarding to continue.'), findsOneWidget);
    expect(find.byKey(const Key('app-shell-scaffold')), findsNothing);
  });
}
