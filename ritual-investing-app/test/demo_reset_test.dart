import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';

import 'support/fixture_services.dart';

void main() {
  test(
    'reset cleanup is awaited before the newer server generation is exposed',
    () async {
      final repository = _PrivacyRepository();
      final container = fixtureContainer(
        sessionBootstrapService: _SequenceBootstrap([
          _bootstrap('account-a', 7),
          _bootstrap('account-a', 8),
        ]),
        includeU11: true,
        privacyRepository: repository,
      );
      addTearDown(container.dispose);
      await container.bootstrap();
      final oldScope = container.featureScope!;

      container.privacyController.prepareDemoReset();
      await container.privacyController.confirmDemoReset(seedVersion: 1);

      expect(repository.resetKeys, ['fixture-privacy-key-00001']);
      expect(repository.cleanupCalls, 1);
      expect(oldScope.isDisposed, isTrue);
      expect(container.memberBootstrap?.accountId, 'account-a');
      expect(container.activeCacheScope?.resetGeneration, 8);
      expect(container.featureScope, isNot(same(oldScope)));
    },
  );

  test(
    'failed old-account privacy cleanup is retried before account B can render',
    () async {
      final repository = _PrivacyRepository()..cleanupFailures = 1;
      final container = fixtureContainer(
        sessionBootstrapService: _SequenceBootstrap([
          _bootstrap('account-a', 4),
          _bootstrap('account-b', 1),
          _bootstrap('account-b', 1),
        ]),
        includeU11: true,
        privacyRepository: repository,
      );
      addTearDown(container.dispose);
      await container.bootstrap();
      final oldScope = container.featureScope!;

      await container.bootstrap();

      expect(repository.cleanupCalls, 2);
      expect(oldScope.isDisposed, isTrue);
      expect(container.memberBootstrap, isNull);
      expect(container.featureScope, isNull);

      await container.bootstrap();

      expect(repository.cleanupCalls, 2);
      expect(container.memberBootstrap?.accountId, 'account-b');
      expect(container.activeCacheScope?.resetGeneration, 1);
    },
  );
}

class _PrivacyRepository implements PrivacyRepository {
  @override
  Future<void> clearStaleLocalFiles() async {}
  int cleanupFailures = 0;
  int cleanupCalls = 0;
  final List<String> resetKeys = [];

  @override
  Future<DemoResetReceipt> resetDemo(
    int seedVersion,
    String idempotencyKey,
  ) async {
    resetKeys.add(idempotencyKey);
    return const DemoResetReceipt(
      resetGeneration: 8,
      defaultPortfolioId: '018f3c2a-4b67-7a89-8abc-123456789099',
    );
  }

  @override
  Future<void> cancelAndClearLocal() async {
    cleanupCalls += 1;
    if (cleanupFailures > 0) {
      cleanupFailures -= 1;
      throw StateError('protected cleanup locked');
    }
  }

  @override
  Future<bool> accountInactive() async => false;

  @override
  Future<void> downloadAndShare(String requestId) => throw UnimplementedError();

  @override
  Future<void> forgetExportId(String requestId) async {}

  @override
  Future<PrivacyExport> getExport(String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> rememberExportId(String requestId) async {}

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey) =>
      throw UnimplementedError();

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) =>
      throw UnimplementedError();

  @override
  Future<String?> restoreExportId() async => null;
}

class _SequenceBootstrap implements SessionBootstrapService {
  _SequenceBootstrap(this.values);

  final List<MemberBootstrap> values;

  @override
  Future<MemberBootstrap> bootstrap() async => values.removeAt(0);
}

MemberBootstrap _bootstrap(String accountId, int resetGeneration) =>
    MemberBootstrap(
      accountId: accountId,
      resetGeneration: resetGeneration,
      onboarding: const MemberOnboardingGate.complete(),
      entitlement: const MemberEntitlement(
        planCode: 'free',
        status: MemberEntitlementStatus.active,
      ),
      defaultPortfolioId: 'fixture-portfolio-$accountId-$resetGeneration',
      serverTime: DateTime.utc(2026, 8, 25),
      contractVersion: '1.0.0',
      themePreference: MemberThemePreference.system,
    );
