import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/cache/read_cache.dart';
import 'repository.dart';

typedef SharePrivateFile = Future<bool> Function(String path);

class PrivateExportShareIncomplete implements Exception {
  const PrivateExportShareIncomplete();
}

class FlutterPrivateExportFiles implements PrivateExportFiles {
  FlutterPrivateExportFiles({
    Future<Directory> Function()? temporaryDirectory,
    SharePrivateFile? shareFile,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _shareFile = shareFile ?? _share;

  final Future<Directory> Function() _temporaryDirectory;
  final SharePrivateFile _shareFile;

  @override
  Future<PrivateExportDelivery> share(
    CacheScope scope,
    String requestId,
    Uint8List bytes,
  ) async {
    if (!_uuid.hasMatch(requestId) || bytes.isEmpty) {
      throw const FormatException('Invalid private export.');
    }
    final directory = await scopeDirectory(scope);
    await directory.create(recursive: true);
    final file = File('${directory.path}/ritual-privacy-$requestId.zip');
    await file.writeAsBytes(bytes, flush: true);
    try {
      if (!await _shareFile(file.path)) {
        throw const PrivateExportShareIncomplete();
      }
      return PrivateExportDelivery.completed;
    } finally {
      if (await file.exists()) await file.delete();
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    }
  }

  @override
  Future<void> clear(CacheScope scope) async {
    final directory = await scopeDirectory(scope);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<Directory> scopeDirectory(CacheScope scope) async {
    final root = await _temporaryDirectory();
    final accountHash = sha256.convert(scope.accountId.codeUnits).toString();
    return Directory(
      '${root.path}/ritual-private-exports-v1/'
      '$accountHash-${scope.resetGeneration}',
    );
  }

  static Future<bool> _share(String path) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/zip')],
        subject: 'Ritual Investing private data export',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      ),
    );
    return result.status == ShareResultStatus.success;
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
