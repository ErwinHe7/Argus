import 'package:flutter/material.dart';

import '../application/onboarding_controller.dart';
import '../domain/onboarding_draft.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        children: [
          Text(
            'Begin with a personal ritual',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Tell us how you invest and how you want Ritual to speak. Your answers shape explanations, research defaults, and recurring Demo plans.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'This takes about 3 minutes. You can keep spirituality practical and skip personalized astrology.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          FilledButton(
            key: const Key('welcome-get-started'),
            onPressed: onGetStarted,
            child: const Text('Get started'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('welcome-sign-in'),
            onPressed: onSignIn,
            child: const Text('Sign in'),
          ),
        ],
      ),
    ),
  );
}

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({
    super.key,
    required this.controller,
    required this.step,
    required this.onContinue,
    required this.onBack,
    this.onDraftChanged,
    this.persistenceMessage,
    this.onRetryPersistence,
  });

  final OnboardingController controller;
  final OnboardingStep step;
  final ValueChanged<OnboardingStep> onContinue;
  final ValueChanged<OnboardingStep> onBack;
  final ValueChanged<OnboardingDraft>? onDraftChanged;
  final String? persistenceMessage;
  final VoidCallback? onRetryPersistence;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final title = _title(step);
      final progress = _progress(
        step,
        controller.draft.astrologyEnabled == true,
      );
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('onboarding-back'),
            tooltip: 'Back',
            onPressed: () => onBack(_previous(step)),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Your Ritual'),
        ),
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Semantics(
                key: const Key('onboarding-step-semantics'),
                container: true,
                header: true,
                label: 'Step ${progress.$1} of ${progress.$2}. $title',
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Progress: Step ${progress.$1} of ${progress.$2}',
                child: LinearProgressIndicator(
                  key: const Key('onboarding-linear-progress'),
                  value: progress.$1 / progress.$2,
                ),
              ),
              if (persistenceMessage != null) ...[
                const SizedBox(height: 16),
                _PersistenceNotice(
                  message: persistenceMessage!,
                  onRetry: onRetryPersistence,
                ),
              ],
              const SizedBox(height: 8),
              Text(_supportingCopy(step)),
              if (step == OnboardingStep.astrologyOptIn &&
                  controller.draft.astrologyEnabled != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  label: controller.draft.astrologyEnabled == true
                      ? 'Personalized astrology selected. Birth date will be Step 10 of 10.'
                      : 'General astrology selected. This remains Step 9 of 9.',
                  child: Text(
                    controller.draft.astrologyEnabled == true
                        ? 'Next: birth date, Step 10 of 10.'
                        : 'No birth date needed. This is Step 9 of 9.',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _question(context),
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('onboarding-next'),
                onPressed: controller.canContinueFor(step)
                    ? () => onContinue(_next(step, controller.draft))
                    : null,
                child: Text(
                  step == OnboardingStep.birthDate ? 'Review' : 'Continue',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _question(BuildContext context) => switch (step) {
    OnboardingStep.experience => _radio<InvestingExperience>(
      controller.draft.experience,
      const {
        InvestingExperience.newToInvesting: 'New to investing',
        InvestingExperience.someExperience: 'I know some of the basics',
        InvestingExperience.experienced: 'Experienced and self-directed',
      },
      controller.setExperience,
    ),
    OnboardingStep.goal => _radio<InvestmentGoal>(controller.draft.goal, const {
      InvestmentGoal.calmFund: 'Build a calmer cushion',
      InvestmentGoal.longTermGrowth: 'Grow over the long term',
      InvestmentGoal.income: 'Explore income ideas',
      InvestmentGoal.exploration: 'Learn through exploration',
    }, controller.setGoal),
    OnboardingStep.horizon => _radio<InvestmentHorizon>(
      controller.draft.horizon,
      const {
        InvestmentHorizon.short: 'Within 3 years',
        InvestmentHorizon.medium: '3 to 7 years',
        InvestmentHorizon.long: 'More than 7 years',
      },
      controller.setHorizon,
    ),
    OnboardingStep.risk => _radio<RiskComfort>(controller.draft.risk, const {
      RiskComfort.low: 'Low — steadier paths',
      RiskComfort.moderate: 'Moderate — some movement is okay',
      RiskComfort.high: 'High — wider swings are okay',
    }, controller.setRisk),
    OnboardingStep.contributionRhythm => _radio<ContributionRhythm>(
      controller.draft.contributionRhythm,
      const {
        ContributionRhythm.weekly: 'Weekly',
        ContributionRhythm.biweekly: 'Every two weeks',
        ContributionRhythm.monthly: 'Monthly',
        ContributionRhythm.irregular: 'Irregularly',
        ContributionRhythm.notSure: 'Not sure yet',
      },
      controller.setContributionRhythm,
    ),
    OnboardingStep.ritualLanguage => _radio<RitualLanguage>(
      controller.draft.ritualLanguage,
      const {
        RitualLanguage.practical: 'Practical and direct',
        RitualLanguage.balanced: 'A balance of practical and mystical',
        RitualLanguage.mystical: 'Mystical and reflective',
        RitualLanguage.preferNotToSay: 'Prefer not to say — keep it neutral',
      },
      controller.setRitualLanguage,
    ),
    OnboardingStep.ritualFamiliarity => _radio<RitualFamiliarity>(
      controller.draft.ritualFamiliarity,
      const {
        RitualFamiliarity.newToRitual: 'New to ritual practices',
        RitualFamiliarity.curious: 'Curious and exploring',
        RitualFamiliarity.familiar: 'Familiar',
        RitualFamiliarity.practiced: 'Part of my regular practice',
        RitualFamiliarity.preferNotToSay: 'Prefer not to say',
      },
      controller.setRitualFamiliarity,
    ),
    OnboardingStep.ritualInterests => Column(
      children: RitualInterest.values
          .map(
            (interest) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              value: controller.draft.ritualInterests.contains(interest),
              title: Text(_interestLabel(interest)),
              onChanged: (selected) {
                final next = Set<RitualInterest>.of(
                  controller.draft.ritualInterests,
                );
                selected == true ? next.add(interest) : next.remove(interest);
                controller.setRitualInterests(next);
                _changed();
              },
            ),
          )
          .toList(),
    ),
    OnboardingStep.astrologyOptIn => _radio<bool>(
      controller.draft.astrologyEnabled,
      const {
        true: 'Personalize with my birth date',
        false: 'Keep astrology general',
      },
      controller.setAstrologyEnabled,
    ),
    OnboardingStep.birthDate => _BirthDateQuestion(
      controller: controller,
      onChanged: _changed,
    ),
    OnboardingStep.welcome || OnboardingStep.review => const SizedBox.shrink(),
  };

  Widget _radio<T>(
    T? selected,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) => RadioGroup<T>(
    groupValue: selected,
    onChanged: (value) {
      if (value == null) return;
      onChanged(value);
      _changed();
    },
    child: Column(
      children: options.entries
          .map(
            (entry) => RadioListTile<T>(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              value: entry.key,
              title: Text(entry.value),
            ),
          )
          .toList(),
    ),
  );

  void _changed() => onDraftChanged?.call(controller.draft);
}

class OnboardingReviewScreen extends StatelessWidget {
  const OnboardingReviewScreen({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onCreateAccount,
    this.onBack,
    this.onDraftChanged,
    this.persistenceMessage,
    this.onRetryPersistence,
  });

  final OnboardingController controller;
  final ValueChanged<OnboardingStep> onEdit;
  final VoidCallback onCreateAccount;
  final VoidCallback? onBack;
  final ValueChanged<OnboardingDraft>? onDraftChanged;
  final String? persistenceMessage;
  final VoidCallback? onRetryPersistence;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final personalization = controller.personalization;
      return Scaffold(
        appBar: AppBar(
          leading: onBack == null
              ? null
              : IconButton(
                  key: const Key('review-back'),
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: const Text('Review your Ritual'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'This is what will shape your experience',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(_personalizationSummary(personalization)),
              if (persistenceMessage != null) ...[
                const SizedBox(height: 16),
                _PersistenceNotice(
                  message: persistenceMessage!,
                  onRetry: onRetryPersistence,
                ),
              ],
              const SizedBox(height: 20),
              _ReviewLine(
                label: 'Investing approach',
                value:
                    '${_label(controller.draft.goal)}, ${_label(controller.draft.horizon)} horizon, ${_label(controller.draft.risk)} risk',
                onEdit: () => onEdit(OnboardingStep.experience),
              ),
              _ReviewLine(
                label: 'Ritual language',
                value: _label(controller.draft.ritualLanguage),
                onEdit: () => onEdit(OnboardingStep.ritualLanguage),
              ),
              _ReviewLine(
                label: 'Astrology',
                value: controller.draft.astrologyEnabled == true
                    ? 'Astrology decision: accepted · Personalized from birth date by the server'
                    : 'Astrology decision: declined · General astrology; no birth data saved',
                onEdit: () => onEdit(OnboardingStep.astrologyOptIn),
              ),
              const Divider(height: 32),
              CheckboxListTile(
                key: const Key('consent-terms'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                value: controller.draft.termsAccepted,
                title: const Text('Terms · version 2026-08'),
                onChanged: (value) => _setConsent(terms: value ?? false),
              ),
              CheckboxListTile(
                key: const Key('consent-privacy'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                value: controller.draft.privacyAccepted,
                title: const Text('Privacy Policy · version 2026-08'),
                onChanged: (value) => _setConsent(privacy: value ?? false),
              ),
              CheckboxListTile(
                key: const Key('consent-demo'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                value: controller.draft.demoAccepted,
                title: const Text('Demo disclosure · version 2026-08'),
                subtitle: const Text(
                  'I understand this is a Demo and no real money moves.',
                ),
                onChanged: (value) => _setConsent(demo: value ?? false),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('review-create-account'),
                onPressed: controller.isReadyForAuthentication
                    ? onCreateAccount
                    : null,
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _setConsent({bool? terms, bool? privacy, bool? demo}) {
    controller.setConsents(
      terms: terms ?? controller.draft.termsAccepted,
      privacy: privacy ?? controller.draft.privacyAccepted,
      demo: demo ?? controller.draft.demoAccepted,
    );
    onDraftChanged?.call(controller.draft);
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.label,
    required this.value,
    required this.onEdit,
  });
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
    trailing: TextButton(onPressed: onEdit, child: const Text('Edit')),
  );
}

class _PersistenceNotice extends StatelessWidget {
  const _PersistenceNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('draft-persistence-message'),
    container: true,
    liveRegion: true,
    label: message,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _BirthDateQuestion extends StatefulWidget {
  const _BirthDateQuestion({required this.controller, required this.onChanged});

  final OnboardingController controller;
  final VoidCallback onChanged;

  @override
  State<_BirthDateQuestion> createState() => _BirthDateQuestionState();
}

class _BirthDateQuestionState extends State<_BirthDateQuestion> {
  String? _errorText;

  void _submit(String raw) {
    final accepted = widget.controller.setBirthDateText(raw);
    setState(() {
      _errorText = accepted
          ? null
          : 'Enter a real date from 1900 through today.';
    });
    if (accepted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.draft.birthDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(selected == null ? 'No date selected' : _friendlyDate(selected)),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('birth-date-manual'),
          initialValue: selected == null ? null : _friendlyDate(selected),
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.done,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Birth date',
            hintText: 'YYYY-MM-DD',
            helperText: 'Enter a date, or use the date picker below.',
          ),
          onFieldSubmitted: _submit,
        ),
        if (_errorText != null)
          Semantics(
            key: const Key('birth-date-error'),
            liveRegion: true,
            label: _errorText,
            child: ExcludeSemantics(
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('birth-date-picker'),
          onPressed: () async {
            final today = widget.controller.today;
            final picked = await showDatePicker(
              context: context,
              initialDate: widget.controller.birthDatePickerInitial,
              firstDate: DateTime(1900),
              lastDate: today,
            );
            if (picked != null && widget.controller.setBirthDate(picked)) {
              if (mounted) setState(() => _errorText = null);
              widget.onChanged();
            }
          },
          child: const Text('Choose birth date'),
        ),
      ],
    );
  }
}

String _title(OnboardingStep step) => switch (step) {
  OnboardingStep.experience => 'How familiar are you with investing?',
  OnboardingStep.goal => 'What are you hoping to explore?',
  OnboardingStep.horizon => 'What time horizon feels relevant?',
  OnboardingStep.risk => 'How much uncertainty feels comfortable?',
  OnboardingStep.contributionRhythm => 'What contribution rhythm fits you?',
  OnboardingStep.ritualLanguage => 'How should Ritual speak to you?',
  OnboardingStep.ritualFamiliarity => 'How familiar are ritual practices?',
  OnboardingStep.ritualInterests => 'What would you like in your ritual?',
  OnboardingStep.astrologyOptIn => 'Would you like personalized astrology?',
  OnboardingStep.birthDate => 'Add your birth date',
  OnboardingStep.welcome => 'Welcome',
  OnboardingStep.review => 'Review',
};

String _supportingCopy(OnboardingStep step) => switch (step) {
  OnboardingStep.risk =>
    'There is no right answer and nothing is selected for you.',
  OnboardingStep.ritualLanguage =>
    'This is a language preference, not a question about religion.',
  OnboardingStep.astrologyOptIn =>
    'Tarot and general astrology remain available either way.',
  OnboardingStep.birthDate =>
    'We ask only for the date. Ritual does not ask for birth time or place.',
  OnboardingStep.ritualInterests => 'Choose one or more.',
  _ => 'Your answer sets a visible default that you can change later.',
};

(int, int) _progress(OnboardingStep step, bool includesBirthDate) {
  const base = [
    OnboardingStep.experience,
    OnboardingStep.goal,
    OnboardingStep.horizon,
    OnboardingStep.risk,
    OnboardingStep.contributionRhythm,
    OnboardingStep.ritualLanguage,
    OnboardingStep.ritualFamiliarity,
    OnboardingStep.ritualInterests,
    OnboardingStep.astrologyOptIn,
  ];
  final steps = includesBirthDate ? [...base, OnboardingStep.birthDate] : base;
  return (steps.indexOf(step) + 1, steps.length);
}

OnboardingStep _next(OnboardingStep step, OnboardingDraft draft) =>
    switch (step) {
      OnboardingStep.welcome => OnboardingStep.experience,
      OnboardingStep.experience => OnboardingStep.goal,
      OnboardingStep.goal => OnboardingStep.horizon,
      OnboardingStep.horizon => OnboardingStep.risk,
      OnboardingStep.risk => OnboardingStep.contributionRhythm,
      OnboardingStep.contributionRhythm => OnboardingStep.ritualLanguage,
      OnboardingStep.ritualLanguage => OnboardingStep.ritualFamiliarity,
      OnboardingStep.ritualFamiliarity => OnboardingStep.ritualInterests,
      OnboardingStep.ritualInterests => OnboardingStep.astrologyOptIn,
      OnboardingStep.astrologyOptIn =>
        draft.astrologyEnabled == true
            ? OnboardingStep.birthDate
            : OnboardingStep.review,
      OnboardingStep.birthDate => OnboardingStep.review,
      OnboardingStep.review => OnboardingStep.review,
    };

OnboardingStep _previous(OnboardingStep step) => switch (step) {
  OnboardingStep.experience => OnboardingStep.welcome,
  OnboardingStep.goal => OnboardingStep.experience,
  OnboardingStep.horizon => OnboardingStep.goal,
  OnboardingStep.risk => OnboardingStep.horizon,
  OnboardingStep.contributionRhythm => OnboardingStep.risk,
  OnboardingStep.ritualLanguage => OnboardingStep.contributionRhythm,
  OnboardingStep.ritualFamiliarity => OnboardingStep.ritualLanguage,
  OnboardingStep.ritualInterests => OnboardingStep.ritualFamiliarity,
  OnboardingStep.astrologyOptIn => OnboardingStep.ritualInterests,
  OnboardingStep.birthDate => OnboardingStep.astrologyOptIn,
  OnboardingStep.review => OnboardingStep.astrologyOptIn,
  OnboardingStep.welcome => OnboardingStep.welcome,
};

String _interestLabel(RitualInterest interest) => switch (interest) {
  RitualInterest.practicalResearch => 'Practical research',
  RitualInterest.tarot => 'Tarot',
  RitualInterest.astrology => 'Astrology',
  RitualInterest.moonCycles => 'Moon cycles',
  RitualInterest.reflection => 'Reflection prompts',
};

String _friendlyDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _personalizationSummary(OnboardingPersonalization value) {
  final depth = switch (value.explanationDepth) {
    ExplanationDepth.foundational => 'Foundational explanations',
    ExplanationDepth.guided => 'Guided explanations',
    ExplanationDepth.concise => 'Concise explanations',
    null => 'Explanation depth not selected',
  };
  return '$depth · ${_label(value.researchGoal)} research · ${_label(value.projectionHorizon)} projections · ${_label(value.recurringDefault)} recurring-plan default.';
}

String _label(Object? value) {
  if (value == null) return 'Not selected';
  return switch (value) {
    InvestmentGoal.calmFund => 'Calm fund',
    InvestmentGoal.longTermGrowth => 'Long-term growth',
    InvestmentGoal.income => 'Income',
    InvestmentGoal.exploration => 'Exploration',
    InvestmentHorizon.short => 'Short',
    InvestmentHorizon.medium => 'Medium',
    InvestmentHorizon.long => 'Long',
    RiskComfort.low => 'Low',
    RiskComfort.moderate => 'Moderate',
    RiskComfort.high => 'High',
    ContributionRhythm.weekly => 'Weekly',
    ContributionRhythm.biweekly => 'Every two weeks',
    ContributionRhythm.monthly => 'Monthly',
    ContributionRhythm.irregular => 'Irregular',
    ContributionRhythm.notSure => 'Not sure',
    RitualLanguage.practical => 'Practical',
    RitualLanguage.balanced => 'Balanced',
    RitualLanguage.mystical => 'Mystical',
    RitualLanguage.preferNotToSay => 'Neutral',
    _ => value.toString(),
  };
}
