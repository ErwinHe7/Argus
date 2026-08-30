import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'member_auth_storage_base.dart';

class ProductionMemberAuthSecureStorage implements MemberAuthSecureStorage {
  ProductionMemberAuthSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'ritual_member_protected_v1',
              migrateWithBackup: false,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
