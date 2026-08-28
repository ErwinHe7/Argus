import 'package:flutter/foundation.dart';

import '../../onboarding/domain/onboarding_draft.dart';

enum ProfileTheme { system, light, dark }

enum ProfileRitualMode { tarot, astrology }

enum ProfileConsentDecision { accepted, declined, withdrawn, unknown }

@immutable
class ProfileDate {
  ProfileDate(this.year, this.month, this.day) {
    final value = DateTime.utc(year, month, day);
    if (year < 1900 ||
        value.year != year ||
        value.month != month ||
        value.day != day) {
      throw ArgumentError.value(toString(), 'birthDate', 'Invalid date.');
    }
  }

  factory ProfileDate.fromDateTime(DateTime value) {
    if (!value.isUtc ||
        value.hour != 0 ||
        value.minute != 0 ||
        value.second != 0 ||
        value.millisecond != 0 ||
        value.microsecond != 0) {
      throw ArgumentError.value(
        value,
        'birthDate',
        'A UTC date-only value is required.',
      );
    }
    return ProfileDate(value.year, value.month, value.day);
  }

  final int year;
  final int month;
  final int day;

  DateTime toUtc({DateTime? today}) {
    final value = DateTime.utc(year, month, day);
    final current = (today ?? DateTime.now()).toUtc();
    final currentDate = DateTime.utc(current.year, current.month, current.day);
    if (value.isAfter(currentDate)) {
      throw ArgumentError.value(value, 'birthDate', 'Future date.');
    }
    return value;
  }

  String get wireValue =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  String toString() => wireValue;

  @override
  bool operator ==(Object other) =>
      other is ProfileDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

@immutable
class SavedRitualPreferences {
  const SavedRitualPreferences({
    required this.locale,
    required this.timezone,
    required this.ritualMode,
    required this.theme,
    required this.version,
    this.ritualFamiliarity,
    this.ritualLanguage,
    this.ritualInterests = const {},
  });

  final String locale;
  final String timezone;
  final RitualFamiliarity? ritualFamiliarity;
  final RitualLanguage? ritualLanguage;
  final Set<RitualInterest> ritualInterests;
  final ProfileRitualMode ritualMode;
  final ProfileTheme theme;
  final int version;

  String get activeVoice => switch (ritualLanguage) {
    RitualLanguage.practical => 'Practical, plain-language guidance',
    RitualLanguage.mystical => 'Mystical language with practical grounding',
    RitualLanguage.balanced => 'Balanced practical and ritual language',
    RitualLanguage.preferNotToSay || null => 'Neutral, practical language',
  };
}

@immutable
class SavedInvestorProfile {
  const SavedInvestorProfile({
    required this.goal,
    required this.horizon,
    required this.risk,
    required this.isDemo,
    required this.version,
    this.experience,
    this.contributionRhythm,
  });

  final InvestingExperience? experience;
  final InvestmentGoal goal;
  final InvestmentHorizon horizon;
  final RiskComfort risk;
  final ContributionRhythm? contributionRhythm;
  final bool isDemo;
  final int version;

  String get explanationDepth => switch (experience) {
    InvestingExperience.newToInvesting => 'Foundational explanations',
    InvestingExperience.someExperience => 'Guided explanations',
    InvestingExperience.experienced => 'Concise explanations',
    null => 'Guided explanations',
  };

  String get researchDefaults =>
      '${goal.label}, ${horizon.label} horizon, ${risk.label} risk framing';

  String get recurringDefault => switch (contributionRhythm) {
    ContributionRhythm.weekly => 'Weekly',
    ContributionRhythm.biweekly => 'Every two weeks',
    ContributionRhythm.monthly => 'Monthly',
    ContributionRhythm.irregular => 'Flexible schedule',
    ContributionRhythm.notSure || null => 'No schedule selected',
  };
}

@immutable
class SavedAstrologyProfile {
  const SavedAstrologyProfile({
    required this.birthDate,
    required this.serverDerivedProfile,
    required this.algorithmVersion,
    required this.version,
  });

  final ProfileDate birthDate;
  final String serverDerivedProfile;
  final String algorithmVersion;
  final int version;
}

@immutable
class ProfileConsentReceipt {
  const ProfileConsentReceipt({
    required this.id,
    required this.decision,
    required this.policyVersion,
    required this.recordedAt,
  });

  final String id;
  final ProfileConsentDecision decision;
  final String policyVersion;
  final DateTime recordedAt;
}

@immutable
class ProfileModel {
  const ProfileModel({
    required this.displayName,
    required this.profileVersion,
    required this.preferences,
    this.investor,
    this.astrology,
    this.astrologyDecision = ProfileConsentDecision.unknown,
    this.lastConsentReceipt,
  });

  final String displayName;
  final int profileVersion;
  final SavedRitualPreferences preferences;
  final SavedInvestorProfile? investor;
  final SavedAstrologyProfile? astrology;
  final ProfileConsentDecision astrologyDecision;
  final ProfileConsentReceipt? lastConsentReceipt;

  ProfileModel copyWith({
    SavedRitualPreferences? preferences,
    SavedInvestorProfile? investor,
    bool clearInvestor = false,
    SavedAstrologyProfile? astrology,
    bool clearAstrology = false,
    ProfileConsentDecision? astrologyDecision,
    ProfileConsentReceipt? lastConsentReceipt,
  }) => ProfileModel(
    displayName: displayName,
    profileVersion: profileVersion,
    preferences: preferences ?? this.preferences,
    investor: clearInvestor ? null : investor ?? this.investor,
    astrology: clearAstrology ? null : astrology ?? this.astrology,
    astrologyDecision: astrologyDecision ?? this.astrologyDecision,
    lastConsentReceipt: lastConsentReceipt ?? this.lastConsentReceipt,
  );
}

@immutable
class ProfilePreferencesUpdate {
  const ProfilePreferencesUpdate({
    required this.expectedVersion,
    this.ritualFamiliarity,
    this.ritualLanguage,
    this.ritualInterests,
    this.ritualMode,
    this.theme,
  });

  final int expectedVersion;
  final RitualFamiliarity? ritualFamiliarity;
  final RitualLanguage? ritualLanguage;
  final Set<RitualInterest>? ritualInterests;
  final ProfileRitualMode? ritualMode;
  final ProfileTheme? theme;
}

@immutable
class ProfileInvestorUpdate {
  const ProfileInvestorUpdate({
    required this.goal,
    required this.horizon,
    required this.risk,
    this.expectedVersion,
    this.experience,
    this.contributionRhythm,
  });

  final InvestingExperience? experience;
  final InvestmentGoal goal;
  final InvestmentHorizon horizon;
  final RiskComfort risk;
  final ContributionRhythm? contributionRhythm;
  final int? expectedVersion;
}

@immutable
class ProfileAstrologyUpdate {
  const ProfileAstrologyUpdate({required this.birthDate, this.expectedVersion});

  final ProfileDate birthDate;
  final int? expectedVersion;
}

extension InvestmentGoalLabel on InvestmentGoal {
  String get label => switch (this) {
    InvestmentGoal.calmFund => 'Calm fund',
    InvestmentGoal.longTermGrowth => 'Long-term growth',
    InvestmentGoal.income => 'Income',
    InvestmentGoal.exploration => 'Exploration',
  };
}

extension InvestmentHorizonLabel on InvestmentHorizon {
  String get label => switch (this) {
    InvestmentHorizon.short => 'Short',
    InvestmentHorizon.medium => 'Medium',
    InvestmentHorizon.long => 'Long',
  };
}

extension RiskComfortLabel on RiskComfort {
  String get label => switch (this) {
    RiskComfort.low => 'Lower',
    RiskComfort.moderate => 'Moderate',
    RiskComfort.high => 'Higher',
  };
}
