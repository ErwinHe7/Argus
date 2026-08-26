import 'package:flutter/foundation.dart';

import '../domain/onboarding_draft.dart';

enum OnboardingStep {
  welcome,
  experience,
  goal,
  horizon,
  risk,
  contributionRhythm,
  ritualLanguage,
  ritualFamiliarity,
  ritualInterests,
  astrologyOptIn,
  birthDate,
  review,
}

enum OnboardingField {
  experience,
  goal,
  horizon,
  risk,
  contributionRhythm,
  ritualLanguage,
  ritualFamiliarity,
  ritualInterests,
  astrologyChoice,
  birthDate,
  termsConsent,
  privacyConsent,
  demoConsent,
}

enum ExplanationDepth { foundational, guided, concise }

enum PersonalizationVoice { practical, balanced, mystical, neutral }

@immutable
class OnboardingPersonalization {
  const OnboardingPersonalization({
    required this.explanationDepth,
    required this.researchGoal,
    required this.projectionHorizon,
    required this.riskDefault,
    required this.recurringDefault,
    required this.voice,
    required this.astrologyPersonalized,
  });

  final ExplanationDepth? explanationDepth;
  final InvestmentGoal? researchGoal;
  final InvestmentHorizon? projectionHorizon;
  final RiskComfort? riskDefault;
  final ContributionRhythm? recurringDefault;
  final PersonalizationVoice? voice;
  final bool astrologyPersonalized;

  factory OnboardingPersonalization.fromDraft(OnboardingDraft draft) =>
      OnboardingPersonalization(
        explanationDepth: switch (draft.experience) {
          InvestingExperience.newToInvesting => ExplanationDepth.foundational,
          InvestingExperience.someExperience => ExplanationDepth.guided,
          InvestingExperience.experienced => ExplanationDepth.concise,
          null => null,
        },
        researchGoal: draft.goal,
        projectionHorizon: draft.horizon,
        riskDefault: draft.risk,
        recurringDefault: draft.contributionRhythm,
        voice: switch (draft.ritualLanguage) {
          RitualLanguage.practical => PersonalizationVoice.practical,
          RitualLanguage.balanced => PersonalizationVoice.balanced,
          RitualLanguage.mystical => PersonalizationVoice.mystical,
          RitualLanguage.preferNotToSay => PersonalizationVoice.neutral,
          null => null,
        },
        astrologyPersonalized:
            draft.astrologyEnabled == true && draft.birthDate != null,
      );
}

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    OnboardingDraft? initialDraft,
    DateTime Function()? now,
  }) : _draft = initialDraft ?? const OnboardingDraft(),
       _now = now ?? DateTime.now;

  OnboardingDraft _draft;
  final DateTime Function() _now;
  OnboardingStep _step = OnboardingStep.welcome;

  OnboardingDraft get draft => _draft;
  OnboardingStep get step => _step;
  OnboardingPersonalization get personalization =>
      OnboardingPersonalization.fromDraft(_draft);
  DateTime get today {
    final value = _now();
    return DateTime(value.year, value.month, value.day);
  }

  DateTime get birthDatePickerInitial {
    final selected = _draft.birthDate;
    if (selected != null &&
        isValidOnboardingBirthDate(selected, today: _now())) {
      return DateTime(selected.year, selected.month, selected.day);
    }
    final current = today;
    final year = current.year - 25 < 1900 ? 1900 : current.year - 25;
    return DateTime(year, current.month, current.day);
  }

  Set<OnboardingField> get validationErrors => {
    if (_draft.experience == null) OnboardingField.experience,
    if (_draft.goal == null) OnboardingField.goal,
    if (_draft.horizon == null) OnboardingField.horizon,
    if (_draft.risk == null) OnboardingField.risk,
    if (_draft.contributionRhythm == null) OnboardingField.contributionRhythm,
    if (_draft.ritualLanguage == null) OnboardingField.ritualLanguage,
    if (_draft.ritualFamiliarity == null) OnboardingField.ritualFamiliarity,
    if (_draft.ritualInterests.isEmpty) OnboardingField.ritualInterests,
    if (_draft.astrologyEnabled == null) OnboardingField.astrologyChoice,
    if (_draft.astrologyEnabled == true &&
        (_draft.birthDate == null ||
            !isValidOnboardingBirthDate(_draft.birthDate!, today: _now())))
      OnboardingField.birthDate,
    if (!_draft.termsAccepted) OnboardingField.termsConsent,
    if (!_draft.privacyAccepted) OnboardingField.privacyConsent,
    if (!_draft.demoAccepted) OnboardingField.demoConsent,
  };

  bool get isReadyForAuthentication => validationErrors.isEmpty;

  bool get canContinue => canContinueFor(_step);

  bool canContinueFor(OnboardingStep step) => switch (step) {
    OnboardingStep.welcome => true,
    OnboardingStep.experience => _draft.experience != null,
    OnboardingStep.goal => _draft.goal != null,
    OnboardingStep.horizon => _draft.horizon != null,
    OnboardingStep.risk => _draft.risk != null,
    OnboardingStep.contributionRhythm => _draft.contributionRhythm != null,
    OnboardingStep.ritualLanguage => _draft.ritualLanguage != null,
    OnboardingStep.ritualFamiliarity => _draft.ritualFamiliarity != null,
    OnboardingStep.ritualInterests => _draft.ritualInterests.isNotEmpty,
    OnboardingStep.astrologyOptIn => _draft.astrologyEnabled != null,
    OnboardingStep.birthDate =>
      _draft.birthDate != null &&
          isValidOnboardingBirthDate(_draft.birthDate!, today: _now()),
    OnboardingStep.review => isReadyForAuthentication,
  };

  void goTo(OnboardingStep value) {
    _step = value;
    notifyListeners();
  }

  void replaceDraft(OnboardingDraft value) {
    _draft = value;
    notifyListeners();
  }

  void reset() {
    _draft = const OnboardingDraft();
    _step = OnboardingStep.welcome;
    notifyListeners();
  }

  void setExperience(InvestingExperience value) =>
      _update(_draft.copyWith(experience: value));
  void setGoal(InvestmentGoal value) => _update(_draft.copyWith(goal: value));
  void setHorizon(InvestmentHorizon value) =>
      _update(_draft.copyWith(horizon: value));
  void setRisk(RiskComfort value) => _update(_draft.copyWith(risk: value));
  void setContributionRhythm(ContributionRhythm value) =>
      _update(_draft.copyWith(contributionRhythm: value));
  void setRitualLanguage(RitualLanguage value) =>
      _update(_draft.copyWith(ritualLanguage: value));
  void setRitualFamiliarity(RitualFamiliarity value) =>
      _update(_draft.copyWith(ritualFamiliarity: value));
  void setRitualInterests(Set<RitualInterest> value) =>
      _update(_draft.copyWith(ritualInterests: Set.unmodifiable(value)));

  void setAstrologyEnabled(bool value) => _update(
    _draft.copyWith(
      astrologyEnabled: value,
      birthDate: value ? _draft.birthDate : null,
    ),
  );

  bool setBirthDate(DateTime value) {
    if (value.hour != 0 ||
        value.minute != 0 ||
        value.second != 0 ||
        value.millisecond != 0 ||
        value.microsecond != 0) {
      return false;
    }
    final date = DateTime.utc(value.year, value.month, value.day);
    if (!isValidOnboardingBirthDate(date, today: _now())) return false;
    _update(_draft.copyWith(birthDate: date));
    return true;
  }

  bool setBirthDateText(String raw) {
    try {
      final value = parseOnboardingBirthDate(raw, today: _now());
      _update(_draft.copyWith(birthDate: value));
      return true;
    } on FormatException {
      return false;
    }
  }

  void setConsents({
    required bool terms,
    required bool privacy,
    required bool demo,
  }) => _update(
    _draft.copyWith(
      termsAccepted: terms,
      privacyAccepted: privacy,
      demoAccepted: demo,
    ),
  );

  void _update(OnboardingDraft value) {
    _draft = value;
    notifyListeners();
  }
}
