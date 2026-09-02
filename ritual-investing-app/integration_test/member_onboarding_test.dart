import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import 'support/member_test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clean install uses Google and asks only for a birth date', (
    tester,
  ) async {
    final harness = await GuidedMemberTestHarness.start();
    addTearDown(harness.close);

    await tester.pumpWidget(RitualInvestingApp(container: harness.container));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome-google-sign-in')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-google-sign-in')));
    await tester.pumpAndSettle();

    expect(harness.googleSignIns, 1);
    expect(find.byKey(const Key('birth-date-manual')), findsOneWidget);
    expect(find.byKey(const Key('recovery-continue')), findsOneWidget);
    expect(find.text('How familiar are you with investing?'), findsNothing);
    expect(find.byKey(const Key('app-shell-scaffold')), findsNothing);
    expect(harness.finalizationPayloads, isEmpty);
    expect(
      harness.allProtectedRequestsAuthorized,
      isTrue,
      reason: harness.safeAuthorizationAudit,
    );
  });

  testWidgets('birth date completion sends the minimal reviewed payload', (
    tester,
  ) async {
    final harness = await GuidedMemberTestHarness.start();
    addTearDown(harness.close);

    await tester.pumpWidget(RitualInvestingApp(container: harness.container));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-google-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('birth-date-manual')),
      '1994-05-14',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('recovery-continue')));
    await tester.tap(find.byKey(const Key('recovery-continue')));
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('app-shell-scaffold')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    expect(harness.finalizationPayloads, [_birthdayOnlyPayload]);
    expect(harness.idempotencyKeys, hasLength(1));
    expect(harness.idempotencyKeys.single, isNotEmpty);
    expect(harness.hasProhibitedPersonalizationKeys, isFalse);
    expect(harness.financeOrBankingRequests, isEmpty);
    expect(
      harness.allProtectedRequestsAuthorized,
      isTrue,
      reason: harness.safeAuthorizationAudit,
    );
  });

  testWidgets('returning completed Google member bypasses birth date setup', (
    tester,
  ) async {
    final harness = await GuidedMemberTestHarness.start(
      initiallyComplete: true,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(RitualInvestingApp(container: harness.container));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome-google-sign-in')), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-google-sign-in')));
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('app-shell-scaffold')).evaluate().isNotEmpty,
    );

    expect(harness.googleSignIns, 1);
    expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    expect(find.byKey(const Key('birth-date-manual')), findsNothing);
    expect(harness.finalizationPayloads, isEmpty);
    expect(
      harness.allProtectedRequestsAuthorized,
      isTrue,
      reason: harness.safeAuthorizationAudit,
    );
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for app state.');
  await tester.pumpAndSettle();
}

const _birthdayOnlyPayload = <String, Object?>{
  'schema_version': 3,
  'expected_onboarding_version': 3,
  'astrology': {'birth_date': '1994-05-14'},
  'consents': {
    'terms': {'policy_version': '2026-08', 'decision': 'accepted'},
    'privacy': {'policy_version': '2026-08', 'decision': 'accepted'},
    'demo_disclosure': {'policy_version': '2026-08', 'decision': 'accepted'},
    'astrology': {'policy_version': '2026-08', 'decision': 'accepted'},
  },
};
