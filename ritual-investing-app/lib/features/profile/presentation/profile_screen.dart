import 'package:flutter/material.dart';

import '../../../core/api/state_status.dart';
import '../../brokerage_connection/application/controller.dart';
import '../../brokerage_connection/domain/model.dart';
import '../../onboarding/domain/onboarding_draft.dart';
import '../../portfolio/application/brokerage_controller.dart';
import '../application/controller.dart';
import '../domain/model.dart';

typedef SaveProfilePreferences = Future<bool> Function(
  ProfilePreferencesUpdate update,
);
typedef SaveProfileInvestor = Future<bool> Function(
  ProfileInvestorUpdate update,
);
typedef SaveProfileAstrology = Future<bool> Function(
  ProfileAstrologyUpdate update,
);
typedef DeleteProfileAstrology = Future<bool> Function({
  required int expectedVersion,
});

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    this.brokerageConnectionController,
    this.brokeragePortfolioController,
    this.onOpenInvesting,
    this.onOpenRitualPreferences,
    this.onOpenAstrology,
    this.onOpenPolicies,
    this.onOpenPlansAndPayment,
    this.onOpenAccount,
    this.onOpenNotifications,
    this.onOpenPrivacy,
    this.onOpenIntentions,
    this.onOpenPortfolio,
  });

  final ProfileController controller;
  final BrokerageConnectionController? brokerageConnectionController;
  final BrokeragePortfolioController? brokeragePortfolioController;
  final VoidCallback? onOpenInvesting;
  final VoidCallback? onOpenRitualPreferences;
  final VoidCallback? onOpenAstrology;
  final VoidCallback? onOpenPolicies;
  final VoidCallback? onOpenPlansAndPayment;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenIntentions;
  final ValueChanged<String>? onOpenPortfolio;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      controller,
      ?brokerageConnectionController,
      ?brokeragePortfolioController,
    ]),
    builder: (context, _) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  label: controller.state.value == null
                      ? 'You'
                      : 'You, ${controller.state.value!.displayName}',
                  excludeSemantics: true,
                  child: Text(
                    'You',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved answers, active personalization, and Webull connection.',
          ),
          StateStatus(phase: controller.state.phase, onRetry: controller.load),
          if (brokerageConnectionController case final value?)
            StateStatus(phase: value.phase, onRetry: value.load),
          if (controller.state.value case final profile?) ...[
            const SizedBox(height: 12),
            if (onOpenInvesting != null)
              _MenuTile(
                key: const Key('you-investing'),
                icon: Icons.trending_up,
                title: 'Investing profile',
                subtitle: profile.investor == null
                    ? 'Add your research preferences'
                    : profile.investor!.explanationDepth,
                onTap: onOpenInvesting,
              ),
            if (onOpenRitualPreferences != null)
              _MenuTile(
                key: const Key('you-ritual-preferences'),
                icon: Icons.tune,
                title: 'Gospel and appearance',
                subtitle: profile.preferences.activeVoice,
                onTap: onOpenRitualPreferences,
              ),
            if (onOpenAstrology != null)
              _MenuTile(
                key: const Key('you-astrology'),
                icon: Icons.auto_awesome_outlined,
                title: 'Astrology',
                subtitle: profile.astrology == null
                    ? 'Optional and currently off'
                    : 'Server-derived profile enabled',
                onTap: onOpenAstrology,
              ),
            if (onOpenPolicies != null)
              _MenuTile(
                key: const Key('you-policies'),
                icon: Icons.verified_user_outlined,
                title: 'Policy decisions',
                subtitle: 'Onboarding consent status',
                onTap: onOpenPolicies,
              ),
            if (onOpenPlansAndPayment != null)
              _MenuTile(
                key: const Key('you-plans-and-payment'),
                icon: Icons.credit_card_outlined,
                title: 'Plans & payment',
                subtitle: 'Paddle plans and the existing Whop checkout',
                onTap: onOpenPlansAndPayment,
              ),
            if (brokerageConnectionController case final brokerage?)
              _MenuTile(
                key: const Key('you-brokerage'),
                icon: Icons.account_balance_outlined,
                title: switch (brokerage.snapshot.phase) {
                  BrokerageConnectionPhase.connected =>
                    brokerage.snapshot.accounts
                            .where((account) => account.selected)
                            .firstOrNull
                            ?.displayLabel ??
                        'Choose a Webull account',
                  BrokerageConnectionPhase.reauthorizationRequired =>
                    'Reconnect Webull',
                  BrokerageConnectionPhase.pending =>
                    'Webull authorization pending',
                  _ => 'Connect Webull',
                },
                subtitle: switch (brokerage.snapshot.phase) {
                  BrokerageConnectionPhase.connected =>
                    'View timestamped provider balances and positions',
                  BrokerageConnectionPhase.reauthorizationRequired =>
                    'Brokerage reads and actions are disabled',
                  BrokerageConnectionPhase.pending =>
                    'Finish in the secure browser',
                  _ => 'Gospel and discovery work without a connection',
                },
                onTap: _brokerageAction(brokerage, onOpenPortfolio),
              ),
            if (onOpenIntentions != null)
              _MenuTile(
                key: const Key('you-intentions'),
                icon: Icons.flag_outlined,
                title: 'Intentions & Future Mirror',
                subtitle: 'Member-entered goals and hypothetical scenarios',
                onTap: onOpenIntentions,
              ),
            if (onOpenNotifications != null)
              _MenuTile(
                key: const Key('you-notifications'),
                icon: Icons.notifications_none,
                title: 'In-app notices',
                subtitle: 'Recap feed and preferences · no push delivery',
                onTap: onOpenNotifications,
              ),
            if (onOpenPrivacy != null)
              _MenuTile(
                key: const Key('you-privacy'),
                icon: Icons.shield_outlined,
                title: 'Privacy and data',
                subtitle: 'Private export and account deletion',
                onTap: onOpenPrivacy,
              ),
            if (onOpenAccount != null)
              _MenuTile(
                key: const Key('you-account'),
                icon: Icons.person_outline,
                title: 'Account',
                subtitle: 'Session and logout',
                onTap: onOpenAccount,
              ),
          ],
        ],
      ),
    ),
  );
}

VoidCallback? _brokerageAction(
  BrokerageConnectionController brokerage,
  ValueChanged<String>? onOpenPortfolio,
) {
  final accountId = brokerage.snapshot.activeAccountId;
  if (accountId != null) {
    return onOpenPortfolio == null ? null : () => onOpenPortfolio(accountId);
  }
  return brokerage.snapshot.requiresReauthorization
      ? brokerage.reconnect
      : brokerage.connect;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      minTileHeight: 56,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class InvestingProfileScreen extends StatefulWidget {
  const InvestingProfileScreen({
    super.key,
    required this.controller,
    required this.onSave,
  });

  final ProfileController controller;
  final SaveProfileInvestor onSave;

  @override
  State<InvestingProfileScreen> createState() => _InvestingProfileScreenState();
}

class _InvestingProfileScreenState extends State<InvestingProfileScreen> {
  InvestingExperience? _experience;
  InvestmentGoal? _goal;
  InvestmentHorizon? _horizon;
  RiskComfort? _risk;
  ContributionRhythm? _rhythm;
  bool _initialized = false;

  void _initialize(ProfileModel value) {
    if (_initialized) return;
    final investor = value.investor;
    _experience = investor?.experience;
    _goal = investor?.goal;
    _horizon = investor?.horizon;
    _risk = investor?.risk;
    _rhythm = investor?.contributionRhythm;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final profile = widget.controller.state.value;
      if (profile != null) _initialize(profile);
      return Scaffold(
        appBar: AppBar(title: const Text('Investing profile')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (profile == null)
                StateStatus(
                  phase: widget.controller.state.phase,
                  onRetry: widget.controller.load,
                ),
              if (profile?.investor case final investor?) ...[
                if (investor.isDemo)
                  const Chip(label: Text('Simulation profile')),
                const SizedBox(height: 16),
                Text(
                  'Active personalization',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Explanation depth',
                  value: investor.explanationDepth,
                ),
                _DetailRow(
                  label: 'Research and projection defaults',
                  value: investor.researchDefaults,
                ),
                _DetailRow(
                  label: 'Recurring-plan default',
                  value: investor.recurringDefault,
                ),
                const SizedBox(height: 20),
              ],
              if (profile != null) ...[
                _Dropdown<InvestingExperience>(
                  label: 'Investing experience',
                  value: _experience,
                  values: InvestingExperience.values,
                  text: _experienceLabel,
                  onChanged: (value) => setState(() => _experience = value),
                ),
                _Dropdown<InvestmentGoal>(
                  label: 'Goal',
                  value: _goal,
                  values: InvestmentGoal.values,
                  text: (value) => value.label,
                  onChanged: (value) => setState(() => _goal = value),
                ),
                _Dropdown<InvestmentHorizon>(
                  label: 'Time horizon',
                  value: _horizon,
                  values: InvestmentHorizon.values,
                  text: (value) => value.label,
                  onChanged: (value) => setState(() => _horizon = value),
                ),
                _Dropdown<RiskComfort>(
                  label: 'Risk comfort',
                  value: _risk,
                  values: RiskComfort.values,
                  text: (value) => value.label,
                  onChanged: (value) => setState(() => _risk = value),
                ),
                _Dropdown<ContributionRhythm>(
                  label: 'Contribution rhythm',
                  value: _rhythm,
                  values: ContributionRhythm.values,
                  text: _rhythmLabel,
                  onChanged: (value) => setState(() => _rhythm = value),
                ),
                _MutationMessage(controller: widget.controller),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('investing-save'),
                  onPressed:
                      widget.controller.isSaving ||
                          _goal == null ||
                          _horizon == null ||
                          _risk == null
                      ? null
                      : () => widget.onSave(
                          ProfileInvestorUpdate(
                            experience: _experience,
                            goal: _goal!,
                            horizon: _horizon!,
                            risk: _risk!,
                            contributionRhythm: _rhythm,
                            expectedVersion: profile.investor?.version,
                          ),
                        ),
                  child: const Text('Save investing profile'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class RitualPreferencesScreen extends StatefulWidget {
  const RitualPreferencesScreen({
    super.key,
    required this.controller,
    required this.onSave,
  });

  final ProfileController controller;
  final SaveProfilePreferences onSave;

  @override
  State<RitualPreferencesScreen> createState() =>
      _RitualPreferencesScreenState();
}

class _RitualPreferencesScreenState extends State<RitualPreferencesScreen> {
  bool _initialized = false;
  ProfileTheme _theme = ProfileTheme.system;
  ProfileRitualMode _mode = ProfileRitualMode.tarot;
  RitualLanguage? _language;
  RitualFamiliarity? _familiarity;
  Set<RitualInterest> _interests = {};

  void _initialize(SavedRitualPreferences value) {
    if (_initialized) return;
    _theme = value.theme;
    _mode = value.ritualMode;
    _language = value.ritualLanguage;
    _familiarity = value.ritualFamiliarity;
    _interests = {...value.ritualInterests};
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final profile = widget.controller.state.value;
      if (profile != null) _initialize(profile.preferences);
      return Scaffold(
        appBar: AppBar(title: const Text('Gospel and appearance')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (profile == null)
                StateStatus(
                  phase: widget.controller.state.phase,
                  onRetry: widget.controller.load,
                ),
              if (profile != null) ...[
                Text(
                  'Active personalization',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Gospel voice',
                  value: profile.preferences.activeVoice,
                ),
                _DetailRow(
                  label: 'Content framing',
                  value: _contentFraming(profile.preferences),
                ),
                const SizedBox(height: 16),
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                for (final theme in ProfileTheme.values)
                  ListTile(
                    key: Key('theme-${theme.name}'),
                    minTileHeight: 48,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _theme == theme
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(_themeLabel(theme)),
                    selected: _theme == theme,
                    onTap: () => setState(() => _theme = theme),
                  ),
                const SizedBox(height: 12),
                _Dropdown<ProfileRitualMode>(
                  label: 'Gospel mode',
                  value: _mode,
                  values: ProfileRitualMode.values,
                  text: (value) =>
                      value == ProfileRitualMode.tarot ? 'Tarot' : 'Astrology',
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                _Dropdown<RitualLanguage>(
                  label: 'Gospel language',
                  value: _language,
                  values: RitualLanguage.values,
                  text: _ritualLanguageLabel,
                  onChanged: (value) => setState(() => _language = value),
                ),
                _Dropdown<RitualFamiliarity>(
                  label: 'Gospel familiarity',
                  value: _familiarity,
                  values: RitualFamiliarity.values,
                  text: _ritualFamiliarityLabel,
                  onChanged: (value) => setState(() => _familiarity = value),
                ),
                Text(
                  'Interests',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final interest in RitualInterest.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _interests.contains(interest),
                    title: Text(_interestLabel(interest)),
                    onChanged: (selected) => setState(() {
                      if (selected ?? false) {
                        _interests.add(interest);
                      } else {
                        _interests.remove(interest);
                      }
                    }),
                  ),
                _MutationMessage(controller: widget.controller),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('preferences-save'),
                  onPressed: widget.controller.isSaving
                      ? null
                      : () => widget.onSave(
                          ProfilePreferencesUpdate(
                            expectedVersion: profile.preferences.version,
                            ritualFamiliarity: _familiarity,
                            ritualLanguage: _language,
                            ritualInterests: _interests,
                            ritualMode: _mode,
                            theme: _theme,
                          ),
                        ),
                  child: const Text('Save preferences'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class AstrologySettingsScreen extends StatefulWidget {
  const AstrologySettingsScreen({
    super.key,
    required this.controller,
    this.onEnable,
    this.onDelete,
  });

  final ProfileController controller;
  final SaveProfileAstrology? onEnable;
  final DeleteProfileAstrology? onDelete;

  @override
  State<AstrologySettingsScreen> createState() =>
      _AstrologySettingsScreenState();
}

class _AstrologySettingsScreenState extends State<AstrologySettingsScreen> {
  final _birthDate = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _birthDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final profile = widget.controller.state.value;
      final astrology = profile?.astrology;
      return Scaffold(
        appBar: AppBar(title: const Text('Astrology')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Astrology is optional. Leo stores a birth date only—never a birth time or place.',
              ),
              if (profile == null)
                StateStatus(
                  phase: widget.controller.state.phase,
                  onRetry: widget.controller.load,
                ),
              if (astrology != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Server-derived profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _DetailRow(
                  label: 'Profile',
                  value: _sentenceCase(astrology.serverDerivedProfile),
                ),
                _DetailRow(
                  label: 'Birth date',
                  value: astrology.birthDate.wireValue,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const Key('astrology-delete'),
                  onPressed: widget.controller.isSaving
                      ? null
                      : () => _confirmDelete(context, astrology.version),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Turn off and delete birth data'),
                ),
              ] else if (profile != null) ...[
                const SizedBox(height: 20),
                TextField(
                  key: const Key('astrology-birth-date'),
                  controller: _birthDate,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Birth date (YYYY-MM-DD)',
                    errorText: _validationMessage,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('astrology-enable'),
                  onPressed: widget.controller.isSaving
                      ? null
                      : () => _enable(profile),
                  child: const Text('Enable astrology'),
                ),
              ],
              _MutationMessage(controller: widget.controller),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _enable(ProfileModel profile) async {
    try {
      final parsed = parseOnboardingBirthDate(
        _birthDate.text.trim(),
        today: DateTime.now().toUtc(),
      );
      setState(() => _validationMessage = null);
      await (widget.onEnable ?? widget.controller.updateAstrology)(
        ProfileAstrologyUpdate(
          birthDate: ProfileDate.fromDateTime(parsed),
          expectedVersion: profile.astrology?.version,
        ),
      );
    } on Object {
      setState(() {
        _validationMessage =
            'Enter a real date from 1900 through today in YYYY-MM-DD format.';
      });
    }
  }

  Future<void> _confirmDelete(BuildContext context, int version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete birth data?'),
        content: const Text(
          'This turns off astrology and asks the server to permanently delete your saved birth date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-astrology-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete birth data'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await (widget.onDelete ?? widget.controller.deleteAstrology)(
        expectedVersion: version,
      );
    }
  }
}

class PolicyStatusScreen extends StatelessWidget {
  const PolicyStatusScreen({
    super.key,
    required this.controller,
    required this.onboardingComplete,
  });

  final ProfileController controller;
  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final profile = controller.state.value;
      return Scaffold(
        appBar: AppBar(title: const Text('Policy decisions')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(
                  onboardingComplete
                      ? 'Onboarding complete'
                      : 'Onboarding incomplete',
                ),
              ),
              const _DetailRow(
                label: 'Terms',
                value: 'A decision is required for current member v2 onboarding; receipt status is not exposed here.',
              ),
              const _DetailRow(
                label: 'Privacy',
                value: 'A decision is required for current member v2 onboarding; receipt status is not exposed here.',
              ),
              const _DetailRow(
                label: 'Simulation disclosure',
                value: 'A decision is required for current member v2 onboarding; receipt status is not exposed here.',
              ),
              _DetailRow(
                label: 'Astrology',
                value: _decisionLabel(
                  profile?.astrologyDecision ?? ProfileConsentDecision.unknown,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The current and detailed consent receipts are not exposed by this API. This screen shows onboarding completion and only decisions known from the current app session or server-backed profile.',
              ),
              if (profile?.lastConsentReceipt case final receipt?) ...[
                const SizedBox(height: 12),
                Text(
                  'Latest write: ${_decisionLabel(receipt.decision)} · ${receipt.policyVersion}',
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Logging out clears this member session from the app.'),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('settings-logout'),
            onPressed: () async {
              try {
                await onLogout();
              } on Object {
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Logout could not finish. Please retry.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) text;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (value) =>
                DropdownMenuItem<T>(value: value, child: Text(text(value))),
          )
          .toList(growable: false),
      onChanged: onChanged,
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

class _MutationMessage extends StatelessWidget {
  const _MutationMessage({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final message = controller.message;
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(message),
      ),
    );
  }
}

String _experienceLabel(InvestingExperience value) => switch (value) {
  InvestingExperience.newToInvesting => 'New to investing',
  InvestingExperience.someExperience => 'Some experience',
  InvestingExperience.experienced => 'Experienced',
};

String _rhythmLabel(ContributionRhythm value) => switch (value) {
  ContributionRhythm.weekly => 'Weekly',
  ContributionRhythm.biweekly => 'Every two weeks',
  ContributionRhythm.monthly => 'Monthly',
  ContributionRhythm.irregular => 'Irregular',
  ContributionRhythm.notSure => 'Not sure',
};

String _themeLabel(ProfileTheme value) => switch (value) {
  ProfileTheme.system => 'Use device setting',
  ProfileTheme.light => 'Light',
  ProfileTheme.dark => 'Dark',
};

String _ritualLanguageLabel(RitualLanguage value) => switch (value) {
  RitualLanguage.practical => 'Practical',
  RitualLanguage.balanced => 'Balanced',
  RitualLanguage.mystical => 'Mystical',
  RitualLanguage.preferNotToSay => 'Prefer not to say',
};

String _ritualFamiliarityLabel(RitualFamiliarity value) => switch (value) {
  RitualFamiliarity.newToRitual => 'New to Gospel guidance',
  RitualFamiliarity.curious => 'Curious',
  RitualFamiliarity.familiar => 'Familiar',
  RitualFamiliarity.practiced => 'Practiced',
  RitualFamiliarity.preferNotToSay => 'Prefer not to say',
};

String _interestLabel(RitualInterest value) => switch (value) {
  RitualInterest.practicalResearch => 'Practical research',
  RitualInterest.tarot => 'Tarot',
  RitualInterest.astrology => 'Astrology',
  RitualInterest.moonCycles => 'Moon cycles',
  RitualInterest.reflection => 'Reflection',
};

String _contentFraming(SavedRitualPreferences preferences) {
  final familiarity = preferences.ritualFamiliarity == null
      ? 'Neutral pacing'
      : '${_ritualFamiliarityLabel(preferences.ritualFamiliarity!)} pacing';
  final interests = preferences.ritualInterests.isEmpty
      ? 'general reflection'
      : (preferences.ritualInterests.map(_interestLabel).toList()..sort()).join(
          ', ',
        );
  return '$familiarity · $interests';
}

String _decisionLabel(ProfileConsentDecision value) => switch (value) {
  ProfileConsentDecision.accepted =>
    'Astrology enabled; a consent receipt is not exposed by this API',
  ProfileConsentDecision.declined => 'Declined in this app session',
  ProfileConsentDecision.withdrawn => 'Withdrawn in this app session',
  ProfileConsentDecision.unknown => 'No current receipt is exposed by this API',
};

String _sentenceCase(String value) {
  final words = value.split('_').join(' ');
  return '${words[0].toUpperCase()}${words.substring(1)}';
}
