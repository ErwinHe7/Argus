import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';

import 'support/member_test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'clean install opt-out finalizes exact personalization before Ritual shell',
    (tester) async {
      final harness = await GuidedMemberTestHarness.start(
        failFirstFinalize: true,
      );
      addTearDown(harness.close);
      await _openCleanInstall(tester, harness);

      await _answer(tester, 'New to investing');
      await _answer(tester, 'Grow over the long term');
      await _answer(tester, 'More than 7 years');
      await _answer(tester, 'Moderate — some movement is okay');
      await _answer(tester, 'Monthly');
      await _answer(tester, 'Practical and direct');
      await _answer(tester, 'Curious and exploring');
      await _chooseInterests(tester, [
        'Practical research',
        'Reflection prompts',
      ]);
      await _answer(tester, 'Keep astrology general');
      await _acceptReviewAndCreate(tester, harness);

      expect(harness.passwordSignUps, const [
        (email: 'new-member@example.com', password: 'test-password'),
      ]);
      expect(find.byKey(const Key('app-shell-scaffold')), findsNothing);
      expect(find.text('Use these reviewed answers?'), findsOneWidget);
      expect(
        harness.protectedValues,
        contains(OnboardingDraftStore.storageKey),
      );

      await tester.tap(find.byKey(const Key('reconcile-attach')));
      await _pumpUntil(
        tester,
        () => harness.idempotencyKeys.length == 1,
        diagnostics: () {
          final state = harness.container.entryCoordinator!.state;
          return 'requests=${harness.requestPaths}; '
              'destination=${state.destination.name}; message=${state.message}';
        },
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('app-shell-scaffold')), findsNothing);
      expect(harness.idempotencyKeys, hasLength(1));
      final firstKey = harness.idempotencyKeys.single;

      await tester.tap(find.byKey(const Key('reconcile-attach')));
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('app-shell-scaffold')).evaluate().isNotEmpty,
      );
      await _pumpUntil(
        tester,
        () => find.text('YOUR DAILY SIGNAL').evaluate().isNotEmpty,
      );

      expect(harness.idempotencyKeys, [firstKey, firstKey]);
      expect(harness.finalizationPayloads, [_optOutPayload, _optOutPayload]);
      expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
      expect(find.text('YOUR DAILY SIGNAL'), findsOneWidget);
      expect(
        harness.protectedValues,
        isNot(contains(OnboardingDraftStore.storageKey)),
      );
      expect(harness.finalizationPayloads.last, _optOutPayload);
      expect(
        (harness.finalizationPayloads.last['astrology'] as Map)['birth_date'],
        isNull,
      );
      expect(harness.hasProhibitedPersonalizationKeys, isFalse);
      expect(harness.financeOrBankingRequests, isEmpty);
      expect(
        harness.allProtectedRequestsAuthorized,
        isTrue,
        reason: harness.safeAuthorizationAudit,
      );
    },
  );

  testWidgets('clean install opt-in sends a civil birth date only', (
    tester,
  ) async {
    final harness = await GuidedMemberTestHarness.start();
    addTearDown(harness.close);
    await _openCleanInstall(tester, harness);

    await _answer(tester, 'Experienced and self-directed');
    await _answer(tester, 'Learn through exploration');
    await _answer(tester, '3 to 7 years');
    await _answer(tester, 'High — wider swings are okay');
    await _answer(tester, 'Every two weeks');
    await _answer(tester, 'Mystical and reflective');
    await _answer(tester, 'Part of my regular practice');
    await _chooseInterests(tester, ['Astrology', 'Moon cycles']);
    await _answer(tester, 'Personalize with my birth date');
    await tester.enterText(
      find.byKey(const Key('birth-date-manual')),
      '1994-05-14',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await _acceptReviewAndCreate(tester, harness);

    expect(find.text('Use these reviewed answers?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reconcile-attach')));
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('app-shell-scaffold')).evaluate().isNotEmpty,
    );
    await _pumpUntil(
      tester,
      () => find.text('YOUR DAILY SIGNAL').evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    final payload = harness.finalizationPayloads.single;
    expect(payload, _optInPayload);
    expect(payload['astrology'], {'enabled': true, 'birth_date': '1994-05-14'});
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

  testWidgets('returning completed sign in bypasses questions', (tester) async {
    final harness = await GuidedMemberTestHarness.start(
      initiallyComplete: true,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(RitualInvestingApp(container: harness.container));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome-sign-in')), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      'returning-member@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'local-test-password',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () => find.text('YOUR DAILY SIGNAL').evaluate().isNotEmpty,
    );

    expect(harness.passwordSignIns, const [
      (email: 'returning-member@example.com', password: 'local-test-password'),
    ]);
    expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
    expect(find.text('YOUR DAILY SIGNAL'), findsOneWidget);
    expect(find.text('How familiar are you with investing?'), findsNothing);
    expect(harness.finalizationPayloads, isEmpty);
    expect(
      harness.allProtectedRequestsAuthorized,
      isTrue,
      reason: harness.safeAuthorizationAudit,
    );
  });
}

Future<void> _openCleanInstall(
  WidgetTester tester,
  GuidedMemberTestHarness harness,
) async {
  await tester.pumpWidget(RitualInvestingApp(container: harness.container));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('welcome-get-started')), findsOneWidget);
  expect(find.byKey(const Key('app-shell-scaffold')), findsNothing);
  await tester.tap(find.byKey(const Key('welcome-get-started')));
  await tester.pumpAndSettle();
}

Future<void> _answer(WidgetTester tester, String answer) async {
  await tester.ensureVisible(find.text(answer));
  await tester.tap(find.text(answer));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('onboarding-next')));
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

Future<void> _chooseInterests(
  WidgetTester tester,
  List<String> interests,
) async {
  for (final interest in interests) {
    await tester.ensureVisible(find.text(interest));
    await tester.tap(find.text(interest));
    await tester.pump();
  }
  await tester.ensureVisible(find.byKey(const Key('onboarding-next')));
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

Future<void> _acceptReviewAndCreate(
  WidgetTester tester,
  GuidedMemberTestHarness harness,
) async {
  for (final key in const [
    Key('consent-terms'),
    Key('consent-privacy'),
    Key('consent-demo'),
  ]) {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(key)).value, isTrue);
  }
  final createAccount = find.byKey(const Key('review-create-account'));
  await _scrollTo(tester, createAccount);
  final onCreateAccount = tester.widget<FilledButton>(createAccount).onPressed;
  expect(onCreateAccount, isNotNull);
  onCreateAccount!();
  await _pumpUntil(
    tester,
    () => find.byKey(const Key('member-sign-in-email')).evaluate().isNotEmpty,
    diagnostics: () =>
        'destination=${harness.container.entryCoordinator!.state.destination}',
  );
  await tester.enterText(
    find.byKey(const Key('member-sign-in-email')),
    'new-member@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('member-sign-in-password')),
    'test-password',
  );
  await tester.tap(find.byKey(const Key('member-sign-in-submit')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final scrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(scrollable, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String Function()? diagnostics,
}) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for app state. ${diagnostics?.call() ?? ''}',
  );
  await tester.pumpAndSettle();
}

const _optOutPayload = <String, Object?>{
  'schema_version': 2,
  'expected_onboarding_version': 3,
  'investing': {
    'experience': 'new',
    'goal_type': 'long_term_growth',
    'time_horizon': 'long',
    'risk_comfort': 'moderate',
    'contribution_rhythm': 'monthly',
  },
  'ritual': {
    'familiarity': 'curious',
    'language_preference': 'practical',
    'interests': ['practical_research', 'reflection'],
  },
  'astrology': {'enabled': false},
  'consents': {
    'terms': {'policy_version': '2026-08', 'decision': 'accepted'},
    'privacy': {'policy_version': '2026-08', 'decision': 'accepted'},
    'demo_disclosure': {'policy_version': '2026-08', 'decision': 'accepted'},
    'astrology': {'policy_version': '2026-08', 'decision': 'declined'},
  },
};

const _optInPayload = <String, Object?>{
  'schema_version': 2,
  'expected_onboarding_version': 3,
  'investing': {
    'experience': 'experienced',
    'goal_type': 'exploration',
    'time_horizon': 'medium',
    'risk_comfort': 'high',
    'contribution_rhythm': 'biweekly',
  },
  'ritual': {
    'familiarity': 'practiced',
    'language_preference': 'mystical',
    'interests': ['astrology', 'moon_cycles'],
  },
  'astrology': {'enabled': true, 'birth_date': '1994-05-14'},
  'consents': {
    'terms': {'policy_version': '2026-08', 'decision': 'accepted'},
    'privacy': {'policy_version': '2026-08', 'decision': 'accepted'},
    'demo_disclosure': {'policy_version': '2026-08', 'decision': 'accepted'},
    'astrology': {'policy_version': '2026-08', 'decision': 'accepted'},
  },
};
