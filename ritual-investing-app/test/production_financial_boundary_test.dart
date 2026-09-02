import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/bootstrap/production_member_feature_scope_factory.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/ritual/data/leonidas_voice_preference_store.dart';
import 'package:ritual_investing_app/features/public_beta/domain/member_capability_policy.dart';

void main() {
  test('public web beta policy keeps financial capabilities unavailable', () {
    const policy = MemberCapabilityPolicy.publicWebBeta;

    for (final capability in const [
      MemberCapability.ritual,
      MemberCapability.discover,
      MemberCapability.coven,
      MemberCapability.you,
      MemberCapability.community,
      MemberCapability.identity,
      MemberCapability.privacy,
    ]) {
      expect(policy.stateOf(capability), MemberCapabilityState.betaBacked);
    }
    for (final capability in const [
      MemberCapability.brokerageConnection,
      MemberCapability.brokeragePortfolio,
      MemberCapability.funding,
      MemberCapability.brokerageOrders,
    ]) {
      expect(policy.stateOf(capability), MemberCapabilityState.unavailable);
      expect(policy.permits(capability), isFalse);
    }
    expect(
      policy.stateOf(MemberCapability.standaloneDemo),
      MemberCapabilityState.standaloneDemoHandoff,
    );

    final factory = File(
      'lib/core/bootstrap/production_member_feature_scope_factory.dart',
    ).readAsStringSync();
    expect(
      factory,
      contains(
        'capabilityPolicy.permits(MemberCapability.brokerageConnection)',
      ),
    );
    expect(
      factory,
      contains('capabilityPolicy.permits(MemberCapability.brokerageOrders)'),
    );

    final container = File(
      'lib/core/bootstrap/production_dependency_container.dart',
    ).readAsStringSync();
    expect(container, contains("config.environment == 'staging'"));
    expect(container, isNot(contains("config.environment == 'beta'")));
  });

  test('public web beta scope constructs no brokerage controllers', () {
    final storage = _MemoryProtectedStorage();
    final repository = _SessionRepository();
    const cacheScope = CacheScope(accountId: 'member-a', resetGeneration: 0);
    final scope =
        ProductionMemberFeatureScopeFactory(
          client: RitualInvestingApiClient(
            basePathOverride: 'https://project.supabase.co/functions/v1/api',
          ),
          pendingCommandStore: PendingCommandStore(storage: storage),
          authController: AuthController(repository: repository),
          privacyExportRequestStore: PrivacyExportRequestStore(
            storage: storage,
          ),
          privateExportFiles: const _PrivateExportFiles(),
          createCommandKey: () => 'command-key',
          now: () => DateTime.utc(2026, 8, 30),
          openBrokerageAuthorization: (_) async => false,
          leonidasVoicePreferenceStore: LeonidasVoicePreferenceStore(storage),
          capabilityPolicy: MemberCapabilityPolicy.publicWebBeta,
        ).call(
          cacheScope,
          ScopedReadCache(storage: MemoryReadCache(), scope: cacheScope),
          MemberBootstrap(
            accountId: 'member-a',
            onboarding: const MemberOnboardingGate.complete(),
            serverTime: DateTime.utc(2026, 8, 30),
            contractVersion: 'argus-member-v1',
            themePreference: MemberThemePreference.system,
          ),
        );
    addTearDown(scope.dispose);

    expect(scope.brokerageConnectionController, isNull);
    expect(scope.brokeragePortfolioController, isNull);
    expect(scope.brokerageOrderController, isNull);
  });

  test(
    'production composition contains Webull commands but no live simulation',
    () {
      final source = File(
        'lib/core/bootstrap/production_member_feature_scope_factory.dart',
      ).readAsStringSync();

      expect(source, contains('GeneratedBrokerageOrderApiService'));
      expect(source, contains('brokerageOrderController:'));
      expect(source, isNot(contains('GeneratedOrderApiService')));
      expect(source, isNot(contains('GeneratedRecurringPlanApiService')));
      expect(source, isNot(contains('GeneratedRebalanceApiService')));
      expect(source, isNot(contains('CachedFundingRepository')));
      expect(source, isNot(contains('GeneratedEntitlementService')));
      expect(source, contains('memberScenarioController:'));
    },
  );

  test('production routes retain brokerage and notifications without Demo authority', () {
    final source = File('lib/features/profile/you_routes.dart')
        .readAsStringSync();

    expect(source, contains('..._brokerageOrderRoutes(container)'));
    expect(source, contains("path: 'notifications'"));
    expect(source, contains("path: 'notification-preferences'"));
    expect(source, contains('..._memberScenarioRoutes(container)'));
    expect(source, isNot(contains("path: 'demo-reset'")));
    expect(source, isNot(contains("path: 'membership'")));
    expect(source, isNot(contains('_simulatedInvestingRoutes')));
  });

  test(
    'Rowan production boundary has no brokerage context or command tool',
    () {
      final rowan = File(
        'lib/features/rowan/data/generated_rowan_api_service.dart',
      ).readAsStringSync();
      final factory = File(
        'lib/core/bootstrap/production_member_feature_scope_factory.dart',
      ).readAsStringSync();

      for (final forbidden in [
        'BrokerageOrder',
        'BrokerageBalance',
        'BrokeragePosition',
        'providerPayload',
        'credential',
        'commandTool',
      ]) {
        expect(rowan, isNot(contains(forbidden)));
      }
      expect(factory, isNot(contains('rowanController: brokerage')));
    },
  );
}

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _PrivateExportFiles implements PrivateExportFiles {
  const _PrivateExportFiles();
  @override
  Future<void> clear(CacheScope scope) async {}
  @override
  Future<PrivateExportDelivery> share(
    CacheScope scope,
    String requestId,
    Uint8List bytes,
  ) async => PrivateExportDelivery.completed;
}

class _SessionRepository implements SessionRepository {
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(
        issuer: 'https://project.supabase.co/auth/v1',
      );
  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();
  @override
  Future<AuthSession?> recover() async => null;
  @override
  Future<void> logout() async {}
}
