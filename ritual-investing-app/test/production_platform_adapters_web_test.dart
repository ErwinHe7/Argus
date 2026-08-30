@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/production_platform_adapters_web.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/privacy/data/private_export_files_web.dart';

void main() {
  test(
    'web production draft composition is tab-scoped and strips consent',
    () async {
      final store = createProductionOnboardingDraftStore(
        nativeStorage: _RejectingStorage(),
        now: () => DateTime.utc(2026, 8, 30),
      );
      addTearDown(store.clear);

      await store.save(
        const OnboardingDraft(
          termsAccepted: true,
          privacyAccepted: true,
          demoAccepted: true,
        ),
      );

      final restored = (await store.read()).draft!;
      expect(restored.termsAccepted, isFalse);
      expect(restored.privacyAccepted, isFalse);
      expect(restored.demoAccepted, isFalse);
    },
  );

  test('web production private exports remain unavailable', () async {
    final files = createProductionPrivateExportFiles();

    await expectLater(
      files.share(
        const CacheScope(accountId: 'account-a', resetGeneration: 1),
        '018f3c2a-4b67-7a89-8abc-123456789020',
        Uint8List.fromList([1]),
      ),
      throwsA(isA<PrivateExportUnavailable>()),
    );
  });
}

class _RejectingStorage implements ProtectedStorage {
  Never _unexpected() => throw StateError('Native storage used on web.');

  @override
  Future<void> delete(String key) async => _unexpected();

  @override
  Future<Map<String, String>> readAll() async => _unexpected();

  @override
  Future<void> write(String key, String value) async => _unexpected();
}
