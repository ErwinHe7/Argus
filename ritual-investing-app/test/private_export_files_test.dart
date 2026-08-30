import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/privacy/data/private_export_files.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ritual-export-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'shares one sanitized ZIP and deletes it immediately afterward',
    () async {
      final observed = <String>[];
      final gateway = FlutterPrivateExportFiles(
        temporaryDirectory: () async => root,
        shareFile: (path) async {
          observed.add(path);
          expect(await File(path).readAsBytes(), [1, 2, 3]);
          expect(path, isNot(contains('token')));
          return true;
        },
      );

      expect(
        await gateway.share(_scope, _requestId, Uint8List.fromList([1, 2, 3])),
        PrivateExportDelivery.completed,
      );

      expect(observed, hasLength(1));
      expect(observed.single, endsWith('ritual-privacy-$_requestId.zip'));
      expect(await File(observed.single).exists(), isFalse);
    },
  );

  test('share failure still removes the private file', () async {
    String? path;
    final gateway = FlutterPrivateExportFiles(
      temporaryDirectory: () async => root,
      shareFile: (value) async {
        path = value;
        throw StateError('share unavailable');
      },
    );

    await expectLater(
      gateway.share(_scope, _requestId, Uint8List.fromList([4, 5, 6])),
      throwsStateError,
    );
    expect(path, isNotNull);
    expect(await File(path!).exists(), isFalse);
  });

  test(
    'dismissed share is incomplete and still removes the private file',
    () async {
      String? path;
      final gateway = FlutterPrivateExportFiles(
        temporaryDirectory: () async => root,
        shareFile: (value) async {
          path = value;
          return false;
        },
      );

      await expectLater(
        gateway.share(_scope, _requestId, Uint8List.fromList([7, 8, 9])),
        throwsA(isA<PrivateExportShareIncomplete>()),
      );
      expect(path, isNotNull);
      expect(await File(path!).exists(), isFalse);
    },
  );

  test('scope cleanup removes only the addressed account generation', () async {
    final gateway = FlutterPrivateExportFiles(
      temporaryDirectory: () async => root,
      shareFile: (_) async => true,
    );
    final a = await gateway.scopeDirectory(_scope);
    final b = await gateway.scopeDirectory(
      const CacheScope(accountId: 'account-b', resetGeneration: 5),
    );
    await a.create(recursive: true);
    await b.create(recursive: true);
    await File('${a.path}/stale.zip').writeAsBytes([1]);
    await File('${b.path}/current.zip').writeAsBytes([2]);

    await gateway.clear(_scope);

    expect(await a.exists(), isFalse);
    expect(await b.exists(), isTrue);
  });
}

const _scope = CacheScope(accountId: 'account-a', resetGeneration: 4);
const _requestId = '018f3c2a-4b67-7a89-8abc-123456789020';
