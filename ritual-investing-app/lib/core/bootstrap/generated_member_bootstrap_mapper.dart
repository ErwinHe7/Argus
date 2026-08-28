import '../../features/brokerage_connection/domain/model.dart';
import '../api/api_failure_mapper.dart';
import 'member_bootstrap.dart';

MemberBootstrap mapSupabaseSessionBootstrap(
  Object? raw,
  BrokerageConnectionSnapshot brokerage,
) {
  final data = _bootstrapObject(raw);
  final member = _bootstrapObject(data['member']);
  final onboarding = data['onboarding'] == null
      ? null
      : _bootstrapObject(data['onboarding']);
  final preferences = data['preferences'] == null
      ? null
      : _bootstrapObject(data['preferences']);
  final investor = data['investor_profile'] == null
      ? const <String, Object?>{}
      : _bootstrapObject(data['investor_profile']);
  final userId = _bootstrapString(member, 'user_id');
  final authorityEpoch = _bootstrapInt(member, 'deletion_epoch');
  final serverTime = DateTime.tryParse(_bootstrapString(data, 'server_time'))
      ?.toUtc();
  if (serverTime == null) ApiFailureMapper.terminalContract();
  return MemberBootstrap(
    accountId: userId,
    authorityEpoch: authorityEpoch,
    resetGeneration: authorityEpoch,
    brokerage: brokerage,
    onboarding: MemberOnboardingGate.fromServer(
      cohort: 'supabase_member_v1',
      currentStep: onboarding == null
          ? 'welcome'
          : _bootstrapString(onboarding, 'current_step'),
      completedAt: onboarding?['completed_at'] == null
          ? null
          : DateTime.tryParse(_bootstrapString(onboarding!, 'completed_at'))
                ?.toUtc(),
      version: onboarding == null ? 0 : _bootstrapInt(onboarding, 'version'),
    ),
    serverTime: serverTime,
    contractVersion: 'supabase-member-v1',
    themePreference: switch (preferences?['theme_mode']) {
      'light' => MemberThemePreference.light,
      'dark' => MemberThemePreference.dark,
      _ => MemberThemePreference.system,
    },
    personalization: MemberPersonalization(
      contributionRhythm: switch (investor['contribution_rhythm']) {
        'weekly' => MemberContributionRhythm.weekly,
        'biweekly' => MemberContributionRhythm.biweekly,
        'monthly' => MemberContributionRhythm.monthly,
        'irregular' => MemberContributionRhythm.irregular,
        'not_sure' => MemberContributionRhythm.notSure,
        _ => MemberContributionRhythm.unavailable,
      },
      explanationDepth: switch (investor['experience']) {
        'new' => MemberExplanationDepth.beginner,
        'some_experience' => MemberExplanationDepth.guided,
        'experienced' => MemberExplanationDepth.advanced,
        _ => MemberExplanationDepth.unavailable,
      },
      ritualVoice: switch (preferences?['ritual_language']) {
        'practical' => MemberRitualVoice.practical,
        'mystical' => MemberRitualVoice.mystical,
        'balanced' || 'prefer_not_to_say' => MemberRitualVoice.balanced,
        _ => MemberRitualVoice.unavailable,
      },
      riskFraming: switch (investor['risk_comfort']) {
        'low' => MemberRiskFraming.low,
        'moderate' => MemberRiskFraming.moderate,
        'high' => MemberRiskFraming.high,
        _ => MemberRiskFraming.unavailable,
      },
      ritualMode: switch (preferences?['ritual_mode']) {
        'tarot' => MemberRitualMode.tarot,
        'astrology' => MemberRitualMode.astrology,
        _ => MemberRitualMode.unavailable,
      },
    ),
  );
}

Map<String, Object?> _bootstrapObject(Object? value) {
  if (value is! Map) ApiFailureMapper.terminalContract();
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) ApiFailureMapper.terminalContract();
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _bootstrapString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    ApiFailureMapper.terminalContract();
  }
  return field;
}

int _bootstrapInt(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! num || field < 0 || field != field.roundToDouble()) {
    ApiFailureMapper.terminalContract();
  }
  return field.toInt();
}
