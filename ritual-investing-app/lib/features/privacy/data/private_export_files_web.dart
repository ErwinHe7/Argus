import 'dart:typed_data';

import '../../../core/cache/read_cache.dart';
import 'repository.dart';

class PrivateExportUnavailable implements Exception {
  const PrivateExportUnavailable();
}

/// The incomplete web beta cannot download, share, or retain export bytes.
class FlutterPrivateExportFiles implements PrivateExportFiles {
  const FlutterPrivateExportFiles();

  @override
  Future<void> share(CacheScope scope, String requestId, Uint8List bytes) =>
      Future<void>.error(const PrivateExportUnavailable());

  @override
  Future<void> clear(CacheScope scope) async {}
}
