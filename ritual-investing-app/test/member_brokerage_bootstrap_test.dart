import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/bootstrap/generated_member_bootstrap_mapper.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';

void main() {
  test(
    'Supabase member bootstrap uses connection authority, not Demo gates',
    () {
      final bootstrap = mapSupabaseSessionBootstrap({
        'member': {
          'user_id': '00000000-0000-4000-8000-000000000001',
          'deletion_epoch': 4,
        },
        'onboarding': {
          'current_step': 'complete',
          'completed_at': '2026-08-28T12:00:00Z',
          'version': 3,
        },
        'preferences': {'theme_mode': 'dark', 'ritual_mode': 'tarot'},
        'investor_profile': {'experience': 'experienced'},
        'server_time': '2026-08-28T12:00:01Z',
        'branch_capabilities': {
          'schema_version': 'member-branch-capabilities-v1',
          'capability_version': 9,
          'environment': 'production',
          'evaluated_at': '2026-08-28T12:00:00Z',
          'expires_at': '2026-08-28T12:05:00Z',
          'branches': ['ritual', 'starpath', 'you'],
        },
      }, const BrokerageConnectionSnapshot.disconnected());

      expect(bootstrap.authorityEpoch, 4);
      expect(bootstrap.themePreference, MemberThemePreference.dark);
      expect(bootstrap.brokerage.phase, BrokerageConnectionPhase.disconnected);
      expect(bootstrap.canEnterMemberShell, isTrue);
      expect(bootstrap.branchCapabilities.capabilityVersion, 9);
      expect(
        bootstrap.branchCapabilities.enabled,
        contains(MemberBranchCapability.starpath),
      );
    },
  );

  test('unknown bootstrap branch capability fails closed', () {
    final bootstrap = mapSupabaseSessionBootstrap({
      'member': {'user_id': 'member-a', 'deletion_epoch': 0},
      'onboarding': {'current_step': 'complete', 'version': 1},
      'server_time': '2026-08-28T12:00:01Z',
      'branch_capabilities': {
        'schema_version': 'member-branch-capabilities-v1',
        'capability_version': 9,
        'environment': 'beta',
        'evaluated_at': '2026-08-28T12:00:00Z',
        'expires_at': '2026-08-28T12:05:00Z',
        'branches': ['ritual', 'future-branch'],
      },
    }, const BrokerageConnectionSnapshot.disconnected());

    expect(bootstrap.branchCapabilities.isAvailable, isFalse);
  });

  test('disconnected brokerage never blocks a completed member shell', () {
    final bootstrap = MemberBootstrap(
      accountId: 'member-a',
      onboarding: const MemberOnboardingGate.complete(),
      serverTime: DateTime.utc(2026, 8, 28),
      contractVersion: 'supabase-member-v1',
      themePreference: MemberThemePreference.system,
      brokerage: const BrokerageConnectionSnapshot.disconnected(),
      entitlement: const MemberEntitlement(
        planCode: 'legacy-demo',
        status: MemberEntitlementStatus.unavailable,
      ),
    );

    expect(bootstrap.canEnterMemberShell, isTrue);
  });
}
