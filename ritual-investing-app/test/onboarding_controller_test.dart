import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/onboarding/application/onboarding_controller.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';

void main() {
  test('risk starts unanswered and blocks forward navigation', () {
    final controller = OnboardingController();
    controller.goTo(OnboardingStep.risk);

    expect(controller.draft.risk, isNull);
    expect(controller.canContinue, isFalse);
  });

  test('astrology decline removes birth data and never blocks review', () {
    final controller = OnboardingController(initialDraft: _completeDraft());
    controller.setAstrologyEnabled(true);
    controller.setBirthDate(DateTime.utc(1994, 5, 14));
    controller.setAstrologyEnabled(false);

    expect(controller.draft.birthDate, isNull);
    expect(controller.personalization.astrologyPersonalized, isFalse);
    expect(controller.validationErrors, isEmpty);
  });

  test('astrology opt-in requires birth date but never time or place', () {
    final controller = OnboardingController(initialDraft: _completeDraft());
    controller.setAstrologyEnabled(true);

    expect(controller.validationErrors, contains(OnboardingField.birthDate));
    expect(controller.draft.toJson(), isNot(contains('birth_time')));
    expect(controller.draft.toJson(), isNot(contains('birth_place')));
  });

  test('birth date setter rejects future and time-bearing values', () {
    final controller = OnboardingController(
      initialDraft: _completeDraft().copyWith(astrologyEnabled: true),
      now: () => DateTime.utc(2026, 8, 24),
    );

    expect(controller.setBirthDate(DateTime.utc(2026, 8, 25)), isFalse);
    expect(controller.setBirthDate(DateTime.utc(1994, 5, 14, 12)), isFalse);
    expect(controller.draft.birthDate, isNull);
    expect(controller.setBirthDate(DateTime(1994, 5, 14)), isTrue);
    expect(controller.draft.birthDate, DateTime.utc(1994, 5, 14));
  });

  test('answers deterministically produce active personalization defaults', () {
    final controller = OnboardingController(initialDraft: _completeDraft());

    expect(
      controller.personalization.explanationDepth,
      ExplanationDepth.foundational,
    );
    expect(
      controller.personalization.researchGoal,
      InvestmentGoal.longTermGrowth,
    );
    expect(
      controller.personalization.projectionHorizon,
      InvestmentHorizon.long,
    );
    expect(controller.personalization.riskDefault, RiskComfort.low);
    expect(
      controller.personalization.recurringDefault,
      ContributionRhythm.weekly,
    );
    expect(controller.personalization.voice, PersonalizationVoice.practical);
  });

  test('required policy and Demo decisions gate reviewed completion', () {
    final controller = OnboardingController(
      initialDraft: _completeDraft().copyWith(demoAccepted: false),
    );

    expect(controller.isReadyForAuthentication, isFalse);
    expect(controller.validationErrors, contains(OnboardingField.demoConsent));
  });
}

OnboardingDraft _completeDraft() => OnboardingDraft(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.longTermGrowth,
  horizon: InvestmentHorizon.long,
  risk: RiskComfort.low,
  contributionRhythm: ContributionRhythm.weekly,
  ritualLanguage: RitualLanguage.practical,
  ritualFamiliarity: RitualFamiliarity.curious,
  ritualInterests: const {RitualInterest.practicalResearch},
  astrologyEnabled: false,
  birthDate: null,
  termsAccepted: true,
  privacyAccepted: true,
  demoAccepted: true,
);
