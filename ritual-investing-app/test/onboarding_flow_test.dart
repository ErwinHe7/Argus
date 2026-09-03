import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/onboarding/application/onboarding_controller.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  testWidgets('welcome offers one direct Google sign-in action', (
    tester,
  ) async {
    var googleSignInCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onContinueWithGoogle: () async => googleSignInCalls++,
        ),
      ),
    );

    expect(find.text('Welcome to Leo'), findsOneWidget);
    expect(find.textContaining('only your birth date'), findsOneWidget);
    expect(find.textContaining('only sign-in method'), findsOneWidget);
    expect(find.byKey(const Key('welcome-artwork')), findsOneWidget);
    expect(
      find.text('Evidence and uncertainty stay within reach.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
    expect(find.text('I have an account'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-google-sign-in')));
    await tester.pumpAndSettle();

    expect(googleSignInCalls, 1);
  });

  testWidgets('welcome reports Google progress and auth failures', (
    tester,
  ) async {
    final barrier = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          message: 'Google sign-in is temporarily unavailable.',
          onContinueWithGoogle: () => barrier.future,
        ),
      ),
    );

    expect(find.byKey(const Key('welcome-auth-message')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('welcome-google-sign-in')));
    await tester.tap(find.byKey(const Key('welcome-google-sign-in')));
    await tester.pump();

    expect(find.text('Opening Google…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('welcome-google-sign-in')))
          .onPressed,
      isNull,
    );

    barrier.complete();
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('authenticated entry asks for birth date only', (tester) async {
    final controller = OnboardingController(
      now: () => DateTime.utc(2026, 8, 24),
    );
    var finishCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BirthdayOnboardingScreen(
          controller: controller,
          onFinish: () async => finishCalls++,
          onLogout: () async {},
        ),
      ),
    );

    expect(find.text('One detail for your sky'), findsOneWidget);
    expect(find.byKey(const Key('birth-date-manual')), findsOneWidget);
    expect(find.text('How familiar are you with investing?'), findsNothing);
    expect(find.textContaining('risk'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('recovery-continue')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('birth-date-manual')),
      '1994-05-14',
    );
    await tester.pump();
    expect(controller.draft.birthDate, DateTime.utc(1994, 5, 14));
    expect(controller.draft.experience, isNull);
    expect(controller.draft.ritualLanguage, isNull);

    await tester.ensureVisible(find.byKey(const Key('recovery-continue')));
    await tester.tap(find.byKey(const Key('recovery-continue')));
    await tester.pumpAndSettle();
    expect(finishCalls, 1);
  });

  testWidgets('risk has no default and announces semantic progress', (
    tester,
  ) async {
    final controller = OnboardingController();
    OnboardingStep? continuedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          controller: controller,
          step: OnboardingStep.risk,
          onContinue: (step) => continuedTo = step,
          onBack: (_) {},
        ),
      ),
    );

    expect(controller.draft.risk, isNull);
    expect(find.text('Step 4 of 9'), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const Key('onboarding-step-semantics')),
    );
    expect(semantics.label, contains('Step 4 of 9'));
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('onboarding-linear-progress')),
    );
    expect(progress.value, closeTo(4 / 9, 0.001));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Low — steadier paths'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    expect(continuedTo, OnboardingStep.contributionRhythm);
  });

  testWidgets('astrology opt-out skips birth date while opt-in requires it', (
    tester,
  ) async {
    final controller = OnboardingController(
      initialDraft: _completeWithoutConsents(),
    )..goTo(OnboardingStep.astrologyOptIn);
    OnboardingStep? next;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          controller: controller,
          step: OnboardingStep.astrologyOptIn,
          onContinue: (value) => next = value,
          onBack: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Keep astrology general'));
    await tester.pump();
    expect(
      find.text('No birth date needed. This is Step 9 of 9.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('onboarding-next')));
    expect(next, OnboardingStep.review);
    expect(controller.draft.birthDate, isNull);

    await tester.tap(find.text('Personalize with my birth date'));
    await tester.pump();
    expect(find.text('Next: birth date, Step 10 of 10.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    expect(next, OnboardingStep.birthDate);
    expect(controller.validationErrors, contains(OnboardingField.birthDate));

    controller.goTo(OnboardingStep.birthDate);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          controller: controller,
          step: OnboardingStep.birthDate,
          onContinue: (value) => next = value,
          onBack: (_) {},
        ),
      ),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('onboarding-step-semantics')))
          .label,
      contains('Step 10 of 10'),
    );
    await tester.enterText(
      find.byKey(const Key('birth-date-manual')),
      '1994-05-14',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(controller.draft.birthDate, DateTime.utc(1994, 5, 14));
  });

  testWidgets(
    'manual birth date rejects normalized calendar overflow accessibly',
    (tester) async {
      final controller = OnboardingController(
        initialDraft: _completeWithoutConsents().copyWith(
          astrologyEnabled: true,
        ),
        now: () => DateTime.utc(2026, 8, 24),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            controller: controller,
            step: OnboardingStep.birthDate,
            onContinue: (_) {},
            onBack: (_) {},
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('birth-date-manual')),
        '2026-02-31',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(controller.draft.birthDate, isNull);
      expect(
        find.text('Enter a real date from 1900 through today.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(const Key('birth-date-error'))).label,
        contains('Enter a real date'),
      );
    },
  );

  testWidgets('native picker clamps an unsafe initial birth date', (
    tester,
  ) async {
    final controller = OnboardingController(
      initialDraft: _completeWithoutConsents().copyWith(
        astrologyEnabled: true,
        birthDate: DateTime.utc(2099, 1, 1),
      ),
      now: () => DateTime.utc(2026, 8, 24),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          controller: controller,
          step: OnboardingStep.birthDate,
          onContinue: (_) {},
          onBack: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('birth-date-picker')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
  });

  testWidgets('review gates account creation on explicit required consents', (
    tester,
  ) async {
    final controller = OnboardingController(
      initialDraft: _completeWithoutConsents(),
    );
    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingReviewScreen(
          controller: controller,
          onEdit: (_) {},
          onPrimaryAction: () => createCalls++,
        ),
      ),
    );

    expect(find.textContaining('Foundational explanations'), findsOneWidget);
    expect(find.text('Terms · version 2026-08'), findsOneWidget);
    expect(find.text('Privacy Policy · version 2026-08'), findsOneWidget);
    expect(
      find.text('Simulation disclosure · version 2026-08'),
      findsOneWidget,
    );
    expect(find.textContaining('Astrology decision: declined'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('review-create-account')),
      240,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review-create-account')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('consent-terms')));
    await tester.tap(find.byKey(const Key('consent-privacy')));
    await tester.tap(find.byKey(const Key('consent-demo')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('review-create-account')),
      240,
    );
    await tester.tap(find.byKey(const Key('review-create-account')));
    expect(createCalls, 1);
  });

  testWidgets('large text keeps question and primary action reachable', (
    tester,
  ) async {
    final controller = OnboardingController()
      ..goTo(OnboardingStep.ritualLanguage);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            accessibleNavigation: true,
            disableAnimations: true,
          ),
          child: OnboardingFlow(
            controller: controller,
            step: OnboardingStep.ritualLanguage,
            onContinue: (_) {},
            onBack: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Practical and direct'));
    await tester.tap(find.text('Practical and direct'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('onboarding-next')),
      200,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
  });

  testWidgets('protected save failure stays visible and retryable', (
    tester,
  ) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          controller: OnboardingController(),
          step: OnboardingStep.experience,
          onContinue: (_) {},
          onBack: (_) {},
          persistenceMessage: 'Your answers are still editable, but could not be saved on this device.',
          onRetryPersistence: () => retryCalls++,
        ),
      ),
    );

    expect(find.byKey(const Key('draft-persistence-message')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCalls, 1);
  });
}

OnboardingDraft _completeWithoutConsents() => const OnboardingDraft(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.longTermGrowth,
  horizon: InvestmentHorizon.long,
  risk: RiskComfort.moderate,
  contributionRhythm: ContributionRhythm.monthly,
  ritualLanguage: RitualLanguage.practical,
  ritualFamiliarity: RitualFamiliarity.curious,
  ritualInterests: {RitualInterest.practicalResearch, RitualInterest.tarot},
  astrologyEnabled: false,
);
