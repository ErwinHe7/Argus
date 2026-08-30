import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

import '../../../core/cache/read_cache.dart';
import 'repository.dart';

typedef CreateBrowserPrivateExportDownload =
    BrowserPrivateExportDownload Function(Uint8List bytes, String mediaType);

abstract interface class BrowserPrivateExportDownload {
  int get byteSize;
  bool start(String fileName);
  void close();
}

class PrivateExportDownloadIncomplete implements Exception {
  const PrivateExportDownloadIncomplete();
}

class FlutterPrivateExportFiles implements PrivateExportFiles {
  FlutterPrivateExportFiles({
    CreateBrowserPrivateExportDownload? createDownload,
  }) : _createDownload = createDownload ?? _createBrowserDownload;

  static const _fileName = 'ritual-private-export.zip';
  static const _mediaType = 'application/zip';

  final CreateBrowserPrivateExportDownload _createDownload;

  @override
  Future<void> share(
    CacheScope scope,
    String requestId,
    Uint8List bytes,
  ) async {
    if (!_uuid.hasMatch(requestId) || bytes.isEmpty) {
      throw const FormatException('Invalid private export.');
    }
    final checksum = sha256.convert(bytes).toString();
    final payload = Uint8List.fromList(bytes);
    BrowserPrivateExportDownload? download;
    try {
      if (payload.length != bytes.length ||
          sha256.convert(payload).toString() != checksum) {
        throw const FormatException('Invalid private export checksum.');
      }
      download = _createDownload(payload, _mediaType);
      if (download.byteSize != payload.length) {
        throw const FormatException('Invalid private export size.');
      }
      if (!download.start(_fileName)) {
        throw const PrivateExportDownloadIncomplete();
      }
      await Future<void>.delayed(Duration.zero);
    } finally {
      download?.close();
      payload.fillRange(0, payload.length, 0);
    }
  }

  @override
  Future<void> clear(CacheScope scope) async {}
}

BrowserPrivateExportDownload _createBrowserDownload(
  Uint8List bytes,
  String mediaType,
) => _DomPrivateExportDownload(bytes, mediaType);

class _DomPrivateExportDownload implements BrowserPrivateExportDownload {
  _DomPrivateExportDownload(Uint8List bytes, String mediaType)
    : _blob = web.Blob(
        <JSAny>[bytes.toJS].toJS,
        web.BlobPropertyBag(type: mediaType),
      ) {
    _objectUrl = web.URL.createObjectURL(_blob);
  }

  final web.Blob _blob;
  late final String _objectUrl;

  @override
  int get byteSize => _blob.size;

  @override
  bool start(String fileName) {
    final body = web.document.body;
    if (body == null) return false;
    final anchor = web.HTMLAnchorElement()
      ..href = _objectUrl
      ..download = fileName
      ..style.display = 'none';
    body.append(anchor);
    try {
      return anchor.dispatchEvent(
        web.MouseEvent(
          'click',
          web.MouseEventInit(bubbles: true, cancelable: true, view: web.window),
        ),
      );
    } on Object {
      return false;
    } finally {
      anchor.remove();
    }
  }

  @override
  void close() => web.URL.revokeObjectURL(_objectUrl);
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
