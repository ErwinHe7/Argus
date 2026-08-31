import 'package:flutter/material.dart';

import '../application/onboarding_controller.dart';
import '../domain/onboarding_draft.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onContinueWithGoogle,
    this.message,
  });

  final Future<void> Function() onContinueWithGoogle;
  final String? message;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isSubmitting = false;

  Future<void> _continueWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onContinueWithGoogle();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacious = constraints.maxHeight >= 760;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, spacious ? 28 : 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LeoBrandLockup(),
                      SizedBox(height: spacious ? 24 : 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          key: const Key('welcome-artwork'),
                          height: spacious ? 252 : 72,
                          child: Image.asset(
                            'assets/images/the-compass.png',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.08),
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      SizedBox(height: spacious ? 28 : 16),
                      Text(
                        'Begin with a personal ritual',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Continue with Google to enter Leo. Your Tarot readings, Starpath, saved research, and preferences stay together across devices.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Google is the only sign-in method. No separate password is needed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (widget.message != null) ...[
                        const SizedBox(height: 16),
                        _WelcomeAuthMessage(message: widget.message!),
                      ],
                      SizedBox(height: spacious ? 28 : 16),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const Key('welcome-google-sign-in'),
                          onPressed: _isSubmitting ? null : _continueWithGoogle,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSubmitting)
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Text(
                                  'G',
                                  semanticsLabel: 'Google',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              const SizedBox(width: 12),
                              Text(
                                _isSubmitting
                                    ? 'Opening Google…'
                                    : 'Continue with Google',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: spacious ? 24 : 16),
                      const _TrustLine(
                        icon: Icons.visibility_outlined,
                        text: 'Evidence and uncertainty stay within reach.',
                      ),
                      const SizedBox(height: 8),
                      const _TrustLine(
                        icon: Icons.tune,
                        text: 'Nothing is chosen or acted on for you.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _WelcomeAuthMessage extends StatelessWidget {
  const _WelcomeAuthMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        key: const Key('welcome-auth-message'),
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: scheme.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeoBrandLockup extends StatelessWidget {
  const _LeoBrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/images/brand/leo-lion.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          semanticLabel: 'Leo lion',
        ),
        const SizedBox(width: 12),
        Text('Leo', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Step ${progress.$1} of ${progress.$2}',
                        key: const Key('onboarding-progress-label'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label:
                            'Progress: Step ${progress.$1} of ${progress.$2}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            key: const Key('onboarding-linear-progress'),
                            value: progress.$1 / progress.$2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
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
                      const SizedBox(height: 10),
                      Text(
                        _supportingCopy(step),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (persistenceMessage != null) ...[
                        const SizedBox(height: 16),
                        _PersistenceNotice(
                          message: persistenceMessage!,
                          onRetry: onRetryPersistence,
                        ),
                      ],
                      if (step == OnboardingStep.astrologyOptIn &&
                          controller.draft.astrologyEnabled != null) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          label: controller.draft.astrologyEnabled == true
                              ? 'Personalized astrology selected. Birth date will be Step 10 of 10.'
                              : 'General astrology selected. This remains Step 9 of 9.',
                          child: Text(
                            controller.draft.astrologyEnabled == true
                                ? 'Next: birth date, Step 10 of 10.'
                                : 'No birth date needed. This is Step 9 of 9.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _question(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: controller.canContinueFor(step)
                      ? () => onContinue(_next(step, controller.draft))
                      : null,
                  child: Text(
                    step == OnboardingStep.birthDate ? 'Review' : 'Continue',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _question(BuildContext context) => switch (step) {
    OnboardingStep.experience => _radio<InvestingExperience>(
      context,
      controller.draft.experience,
      const {
        InvestingExperience.newToInvesting: 'New to investing',
        InvestingExperience.someExperience: 'I know some of the basics',
        InvestingExperience.experienced: 'Experienced and self-directed',
      },
      controller.setExperience,
    ),
    OnboardingStep.goal => _radio<InvestmentGoal>(
      context,
      controller.draft.goal,
      const {
        InvestmentGoal.calmFund: 'Build a calmer cushion',
        InvestmentGoal.longTermGrowth: 'Grow over the long term',
        InvestmentGoal.income: 'Explore income ideas',
        InvestmentGoal.exploration: 'Learn through exploration',
      },
      controller.setGoal,
    ),
    OnboardingStep.horizon => _radio<InvestmentHorizon>(
      context,
      controller.draft.horizon,
      const {
        InvestmentHorizon.short: 'Within 3 years',
        InvestmentHorizon.medium: '3 to 7 years',
        InvestmentHorizon.long: 'More than 7 years',
      },
      controller.setHorizon,
    ),
    OnboardingStep.risk => _radio<RiskComfort>(
      context,
      controller.draft.risk,
      const {
        RiskComfort.low: 'Low — steadier paths',
        RiskComfort.moderate: 'Moderate — some movement is okay',
        RiskComfort.high: 'High — wider swings are okay',
      },
      controller.setRisk,
    ),
    OnboardingStep.contributionRhythm => _radio<ContributionRhythm>(
      context,
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
      context,
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
      context,
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
            (interest) => _choiceSurface(
              context,
              selected: controller.draft.ritualInterests.contains(interest),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                minTileHeight: 56,
                value: controller.draft.ritualInterests.contains(interest),
                selected: controller.draft.ritualInterests.contains(interest),
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
            ),
          )
          .toList(),
    ),
    OnboardingStep.astrologyOptIn => _radio<bool>(
      context,
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
    BuildContext context,
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
            (entry) => _choiceSurface(
              context,
              selected: selected == entry.key,
              child: RadioListTile<T>(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                minTileHeight: 56,
                value: entry.key,
                selected: selected == entry.key,
                title: Text(entry.value),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _choiceSurface(
    BuildContext context, {
    required bool selected,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selectedAlpha = Theme.of(context).brightness == Brightness.dark
        ? 0.18
        : 0.08;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: selectedAlpha)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? scheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  void _changed() => onDraftChanged?.call(controller.draft);
}

class OnboardingReviewScreen extends StatelessWidget {
  const OnboardingReviewScreen({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onPrimaryAction,
    this.primaryActionLabel = 'Create account',
    this.onBack,
    this.onDraftChanged,
    this.persistenceMessage,
    this.onRetryPersistence,
  });

  final OnboardingController controller;
  final ValueChanged<OnboardingStep> onEdit;
  final VoidCallback onPrimaryAction;
  final String primaryActionLabel;
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'This is what will shape your experience',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _personalizationSummary(personalization),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (persistenceMessage != null) ...[
                        const SizedBox(height: 16),
                        _PersistenceNotice(
                          message: persistenceMessage!,
                          onRetry: onRetryPersistence,
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Your defaults',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 24),
                      Text(
                        'Required consents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _ReviewConsent(
                        key: const Key('consent-terms'),
                        value: controller.draft.termsAccepted,
                        title: 'Terms · version 2026-08',
                        onChanged: (value) => _setConsent(terms: value),
                      ),
                      _ReviewConsent(
                        key: const Key('consent-privacy'),
                        value: controller.draft.privacyAccepted,
                        title: 'Privacy Policy · version 2026-08',
                        onChanged: (value) => _setConsent(privacy: value),
                      ),
                      _ReviewConsent(
                        key: const Key('consent-demo'),
                        value: controller.draft.demoAccepted,
                        title: 'Demo disclosure · version 2026-08',
                        subtitle: 'I understand this is a Demo and no real money moves.',
                        onChanged: (value) => _setConsent(demo: value),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('review-create-account'),
                          onPressed: controller.isReadyForAuthentication
                              ? onPrimaryAction
                              : null,
                          child: Text(primaryActionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

class _ReviewConsent extends StatelessWidget {
  const _ReviewConsent({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: value
            ? scheme.primary.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.08,
              )
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: value ? scheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          value: value,
          selected: value,
          minTileHeight: 56,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          onChanged: (next) => onChanged(next ?? false),
        ),
      ),
    );
  }
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
    child: Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.cloud_off_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
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
