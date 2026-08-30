import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';

void main() {
  test('production member composition delegates native-only adapters', () {
    final source = File(
      'lib/core/bootstrap/production_dependency_container.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("package:app_links/app_links.dart")));
    expect(source, isNot(contains('package:path_provider/path_provider.dart')));
    expect(source, isNot(contains('AppLinks()')));
    expect(source, isNot(contains('FlutterPrivateExportFiles()')));
  });

  test('web scaffold is local-only and has no service-worker bootstrap', () {
    final source = File('web/index.html').readAsStringSync();

    expect(source, contains('flutter_bootstrap.js'));
    expect(source, isNot(contains('http://')));
    expect(source, isNot(contains('https://')));
    expect(source, isNot(contains('serviceWorker')));
  });

  test('web draft persistence never restores consent authority', () async {
    final storage = _MemoryProtectedStorage();
    final store = OnboardingDraftStore(
      storage: storage,
      installation: const FixedInstallationBinding('tab-a'),
      now: () => DateTime.utc(2026, 8, 30),
      persistConsentAuthority: false,
    );
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
  });
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
