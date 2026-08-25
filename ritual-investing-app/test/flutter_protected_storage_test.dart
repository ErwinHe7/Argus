import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/flutter_protected_storage.dart';

void main() {
  test(
    'protected storage adapter uses an injectable device-only driver',
    () async {
      final driver = _MemoryProtectedStorageDriver();
      final storage = FlutterProtectedStorage(driver: driver);

      await storage.write('pending', 'ciphertext');
      expect(await storage.readAll(), {'pending': 'ciphertext'});
      await storage.delete('pending');
      expect(await storage.readAll(), isEmpty);
    },
  );
}

class _MemoryProtectedStorageDriver implements ProtectedStorageDriver {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
