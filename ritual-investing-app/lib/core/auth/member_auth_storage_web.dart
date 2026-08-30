import 'dart:js_interop';

import 'member_auth_storage_base.dart';

@JS('window.sessionStorage')
external _BrowserStorage get _sessionStorage;

extension type _BrowserStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

class ProductionMemberAuthSecureStorage implements MemberAuthSecureStorage {
  const ProductionMemberAuthSecureStorage();

  static const _prefix = 'ritual-member-auth-web-v1:';
  String _key(String key) => '$_prefix$key';

  @override
  Future<String?> read(String key) async => _sessionStorage.getItem(_key(key));
  @override
  Future<void> write(String key, String value) async =>
      _sessionStorage.setItem(_key(key), value);
  @override
  Future<void> delete(String key) async =>
      _sessionStorage.removeItem(_key(key));
}
