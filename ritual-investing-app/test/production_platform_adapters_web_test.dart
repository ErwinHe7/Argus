@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/production_platform_adapters_web.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/onboarding/data/onboarding_draft_store.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/privacy/data/private_export_files_web.dart';

void main() {
  test(
    'web production draft composition is tab-scoped and strips consent',
    () async {
      final store = createProductionOnboardingDraftStore(
        nativeStorage: _RejectingStorage(),
        now: () => DateTime.utc(2026, 8, 30),
      );
      addTearDown(store.clear);

      await store.save(
        const OnboardingDraft(
          termsAccepted: true,
          privacyAccepted: true,
          demoAccepted: true,
        ),
      );

      final restored = (await store.read()).draft!;
      expect(restored.termsAccepted, isFalse);
      expect(restored.privacyAccepted, isFalse);
      expect(restored.demoAccepted, isFalse);

      await store.clear();
      expect((await store.read()).status, DraftReadStatus.empty);
    },
  );

  test(
    'web private export uses safe metadata and releases its download',
    () async {
      _FakeBrowserDownload? download;
      final files = FlutterPrivateExportFiles(
        createDownload: (bytes, mediaType) {
          final created = _FakeBrowserDownload(bytes.length);
          download = created;
          expect(bytes, [1, 2, 3]);
          expect(mediaType, 'application/zip');
          return created;
        },
      );

      await files.share(
        const CacheScope(accountId: 'account-a', resetGeneration: 1),
        '018f3c2a-4b67-7a89-8abc-123456789020',
        Uint8List.fromList([1, 2, 3]),
      );

      expect(download!.fileName, 'ritual-private-export.zip');
      expect(download!.started, isTrue);
      expect(download!.closed, isTrue);
    },
  );

  test(
    'blocked web download remains retryable and releases each object',
    () async {
      final downloads = <_FakeBrowserDownload>[];
      final files = FlutterPrivateExportFiles(
        createDownload: (bytes, mediaType) {
          final download = _FakeBrowserDownload(
            bytes.length,
            canStart: downloads.isNotEmpty,
          );
          downloads.add(download);
          return download;
        },
      );

      await expectLater(
        files.share(
          const CacheScope(accountId: 'account-a', resetGeneration: 1),
          '018f3c2a-4b67-7a89-8abc-123456789020',
          Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<PrivateExportDownloadIncomplete>()),
      );
      expect(downloads.single.closed, isTrue);

      await expectLater(
        files.share(
          const CacheScope(accountId: 'account-a', resetGeneration: 1),
          '018f3c2a-4b67-7a89-8abc-123456789020',
          Uint8List.fromList([1, 2, 3]),
        ),
        completes,
      );
      expect(downloads, hasLength(2));
      expect(downloads.last.closed, isTrue);
    },
  );
}

class _FakeBrowserDownload implements BrowserPrivateExportDownload {
  _FakeBrowserDownload(this.byteSize, {this.canStart = true});

  @override
  final int byteSize;
  final bool canStart;
  bool started = false;
  bool closed = false;
  String? fileName;

  @override
  bool start(String value) {
    started = true;
    fileName = value;
    return canStart;
  }

  @override
  void close() => closed = true;
}

class _RejectingStorage implements ProtectedStorage {
  Never _unexpected() => throw StateError('Native storage used on web.');

  @override
  Future<void> delete(String key) async => _unexpected();

  @override
  Future<Map<String, String>> readAll() async => _unexpected();

  @override
  Future<void> write(String key, String value) async => _unexpected();
}
