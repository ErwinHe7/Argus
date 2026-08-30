import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import '../../../core/api/pending_command_store.dart';
import 'onboarding_draft_store.dart';

const _storageNamespace = 'ritual-onboarding-web-v1:';

@JS('window.sessionStorage')
external BrowserStorage get _sessionStorage;

extension type BrowserStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

class BrowserSessionOnboardingStorage implements ProtectedStorage {
  BrowserSessionOnboardingStorage({BrowserStorage? storage})
    : _storage = storage ?? _sessionStorage;

  final BrowserStorage _storage;

  String _key(String key) => '$_storageNamespace$key';

  @override
  Future<Map<String, String>> readAll() async {
    final value = _storage.getItem(_key(OnboardingDraftStore.storageKey));
    return value == null ? const {} : {OnboardingDraftStore.storageKey: value};
  }

  @override
  Future<void> write(String key, String value) async {
    if (key != OnboardingDraftStore.storageKey) {
      throw StateError('Browser onboarding storage rejects unrelated data.');
    }
    _storage.setItem(_key(key), value);
  }

  @override
  Future<void> delete(String key) async => _storage.removeItem(_key(key));
}

/// Cleanup namespace only; it is not authentication or authorization state.
class BrowserTabInstallationBinding implements InstallationBinding {
  BrowserTabInstallationBinding({BrowserStorage? storage, Random? random})
    : _storage = storage ?? _sessionStorage,
      _random = random ?? Random.secure();

  static const _key = '${_storageNamespace}tab-id';
  final BrowserStorage _storage;
  final Random _random;

  @override
  Future<String> currentId() async {
    final existing = _storage.getItem(_key);
    if (existing != null && existing.length == 32) return existing;
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final created = base64Url.encode(bytes).replaceAll('=', '');
    _storage.setItem(_key, created);
    return created;
  }
}
