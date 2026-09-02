import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/bootstrap/app_runtime.dart';
import 'package:ritual_investing_app/core/bootstrap/member_shell_runtime.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';
import 'package:ritual_investing_app/features/ritual/data/leonidas_voice_preference_store.dart';

import 'support/fixture_services.dart';

void main() {
  test(
    'completed member runtime starts at the shell and owns its scope directly',
    () async {
      final production = fixtureContainer();
      addTearDown(production.dispose);
      await production.bootstrap();
      final bootstrap = production.memberBootstrap!;
      final scope = production.featureScope!;

      final runtime = MemberShellRuntime.completed(
        bootstrap: bootstrap,
        featureScope: scope,
      );

      expect(runtime.entryGate, MemberEntryGate.member);
      expect(runtime.memberBootstrap, same(bootstrap));
      expect(runtime.featureScope, same(scope));

      await runtime.ensureBranchLoaded(MemberBranch.ritual);
      expect(runtime.dailyRitualController.state.value, isNotNull);

      runtime.dispose();
      expect(scope.isDisposed, isTrue);
    },
  );

  test('production container delegates active shell ownership', () async {
    final container = fixtureContainer();
    addTearDown(container.dispose);

    await container.bootstrap();

    expect(container.memberShellRuntime, isA<MemberShellRuntime>());
    expect(
      container.memberShellRuntime.featureScope,
      same(container.featureScope),
    );
    expect(container.entryGate, MemberEntryGate.member);

    await container.logout();

    expect(container.memberShellRuntime.featureScope, isNull);
    expect(container.entryGate, MemberEntryGate.signedOut);
  });

  test(
    'confirmed deletion clears the scoped voice setting before logout',
    () async {
      final preferenceStore = _BlockingPreferenceStore();
      final container = fixtureContainer(
        includeU11: true,
        privacyRepository: _DeletionPrivacyRepository(),
        leonidasVoicePreferenceStore: preferenceStore,
      );
      addTearDown(container.dispose);
      await container.bootstrap();
      final activeScope = container.activeCacheScope!;
      final privacy = container.featureScope!.privacyController!;

      privacy.prepareDeletion();
      final confirmation = privacy.confirmDeletion();
      await preferenceStore.clearStarted.future;

      expect(preferenceStore.clearedScope, activeScope);
      expect(container.featureScope, isNotNull);
      expect(container.entryGate, MemberEntryGate.member);

      preferenceStore.releaseClear.complete();
      await confirmation;

      expect(container.featureScope, isNull);
      expect(container.entryGate, MemberEntryGate.signedOut);
    },
  );

  test(
    'voice cleanup failure cannot block confirmed deletion logout',
    () async {
      final container = fixtureContainer(
        includeU11: true,
        privacyRepository: _DeletionPrivacyRepository(),
        leonidasVoicePreferenceStore: _FailingPreferenceStore(),
      );
      addTearDown(container.dispose);
      await container.bootstrap();
      final privacy = container.featureScope!.privacyController!;

      privacy.prepareDeletion();
      await privacy.confirmDeletion();

      expect(container.featureScope, isNull);
      expect(container.entryGate, MemberEntryGate.signedOut);
    },
  );
}

class _BlockingPreferenceStore implements LeonidasVoicePreferencePersistence {
  final clearStarted = Completer<void>();
  final releaseClear = Completer<void>();
  CacheScope? clearedScope;

  @override
  Future<void> clearScope(CacheScope scope) async {
    clearedScope = scope;
    clearStarted.complete();
    await releaseClear.future;
  }

  @override
  Future<LeonidasVoicePreference> read(CacheScope scope) async =>
      LeonidasVoicePreference.enabled;

  @override
  Future<void> write(CacheScope scope, {required bool enabled}) async {}
}

class _DeletionPrivacyRepository implements PrivacyRepository {
  @override
  Future<bool> accountInactive() async => false;

  @override
  Future<void> cancelAndClearLocal() async {}

  @override
  Future<void> clearStaleLocalFiles() async {}

  @override
  Future<PrivateExportDelivery> downloadAndShare(String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> forgetExportId(String requestId) async {}

  @override
  Future<PrivacyExport> getExport(String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> rememberExportId(String requestId) async {}

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(
    String idempotencyKey,
    String stepUpReceipt,
  ) async => PrivacyDeletionReceipt(
    requestId: '018f3c2a-4b67-7a89-8abc-123456789021',
    status: PrivacyDeletionStatus.queued,
    requestedAt: DateTime.utc(2026, 9, 2),
  );

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) =>
      throw UnimplementedError();

  @override
  Future<String?> restoreExportId() async => null;
}

class _FailingPreferenceStore implements LeonidasVoicePreferencePersistence {
  @override
  Future<void> clearScope(CacheScope scope) => throw StateError('locked');

  @override
  Future<LeonidasVoicePreference> read(CacheScope scope) async =>
      LeonidasVoicePreference.disabled;

  @override
  Future<void> write(CacheScope scope, {required bool enabled}) async {}
}
