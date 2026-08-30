import 'package:web/web.dart' as web;

import '../../features/brokerage_connection/data/repository.dart';
import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_installation_binding_web.dart';
import '../../features/privacy/data/private_export_files_web.dart';
import '../../features/privacy/data/repository.dart';
import '../api/pending_command_store.dart';
import '../auth/member_auth.dart';
import 'entry_coordinator.dart';

const _memberStateNamespace = 'ritual-member-state-web-v1:';

class BrowserSessionProtectedStorage implements ProtectedStorage {
  BrowserSessionProtectedStorage({web.Storage? storage})
    : _storage = storage ?? web.window.sessionStorage;

  final web.Storage _storage;

  String _key(String key) {
    if (key.isEmpty ||
        key.length > 256 ||
        key.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw ArgumentError.value(key, 'key', 'Invalid protected-storage key.');
    }
    return '$_memberStateNamespace$key';
  }

  @override
  Future<Map<String, String>> readAll() async {
    final values = <String, String>{};
    for (var index = 0; index < _storage.length; index++) {
      final storedKey = _storage.key(index);
      if (storedKey == null || !storedKey.startsWith(_memberStateNamespace)) {
        continue;
      }
      final value = _storage.getItem(storedKey);
      if (value != null) {
        values[storedKey.substring(_memberStateNamespace.length)] = value;
      }
    }
    return values;
  }

  @override
  Future<void> write(String key, String value) async =>
      _storage.setItem(_key(key), value);

  @override
  Future<void> delete(String key) async => _storage.removeItem(_key(key));
}

ProtectedStorage createProductionProtectedStorage() =>
    BrowserSessionProtectedStorage();

OnboardingDraftStore createProductionOnboardingDraftStore({
  required ProtectedStorage nativeStorage,
  required DateTime Function() now,
}) => OnboardingDraftStore(
  storage: BrowserSessionOnboardingStorage(),
  installation: BrowserTabInstallationBinding(),
  now: now,
  persistConsentAuthority: false,
);

PrivateExportFiles createProductionPrivateExportFiles() =>
    FlutterPrivateExportFiles();

void bindProductionBrokerageNativeLinks({
  required EntryCoordinator coordinator,
  required MemberNativeLinkPolicy policy,
  required BrokerageConnectionRepository Function() brokerageConnections,
}) {
  // Native-link plugins and provider-completion redemption stay absent on web.
}
