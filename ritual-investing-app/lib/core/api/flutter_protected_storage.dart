import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pending_command_store.dart';

abstract interface class ProtectedStorageDriver {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterProtectedStorage implements ProtectedStorage {
  FlutterProtectedStorage({ProtectedStorageDriver? driver})
    : _driver = driver ?? FlutterSecureStorageDriver.deviceOnly();

  final ProtectedStorageDriver _driver;

  @override
  Future<Map<String, String>> readAll() => _driver.readAll();

  @override
  Future<void> write(String key, String value) => _driver.write(key, value);

  @override
  Future<void> delete(String key) => _driver.delete(key);
}

class FlutterSecureStorageDriver implements ProtectedStorageDriver {
  FlutterSecureStorageDriver._(this._storage);

  factory FlutterSecureStorageDriver.deviceOnly() =>
      FlutterSecureStorageDriver._(
        const FlutterSecureStorage(
          aOptions: AndroidOptions(
            storageNamespace: 'ritual_member_protected_v1',
            migrateWithBackup: false,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
            synchronizable: false,
          ),
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
