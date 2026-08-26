import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/api/pending_command_store.dart';
import '../domain/onboarding_draft.dart';

enum DraftReadStatus {
  empty,
  available,
  expired,
  corrupted,
  undecryptable,
  orphaned,
  locked,
}

class DraftReadResult {
  const DraftReadResult(this.status, [this.draft]);

  final DraftReadStatus status;
  final OnboardingDraft? draft;
}

class ProtectedStorageLocked implements Exception {
  const ProtectedStorageLocked();
}

class ProtectedStorageUndecryptable implements Exception {
  const ProtectedStorageUndecryptable();
}

abstract interface class InstallationBinding {
  Future<String> currentId();
}

class FixedInstallationBinding implements InstallationBinding {
  const FixedInstallationBinding(this.value);

  final String value;

  @override
  Future<String> currentId() async => value;
}

/// Binds protected onboarding data to this installation through a non-backed-up
/// app-container cache marker.
///
/// Cache eviction intentionally fails closed: a replacement marker makes an
/// existing protected draft orphaned, and [OnboardingDraftStore.read] purges it.
class AppContainerInstallationBinding implements InstallationBinding {
  AppContainerInstallationBinding({
    required this.cacheDirectoryProvider,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const fileName = '.onboarding-install-v1';
  final Future<Directory> Function() cacheDirectoryProvider;
  final Random _random;
  Future<String>? _resolvedId;

  @override
  Future<String> currentId() => _resolvedId ??= _readOrCreate();

  Future<String> _readOrCreate() async {
    final directory = await cacheDirectoryProvider();
    if (!await directory.exists()) await directory.create(recursive: true);
    final marker = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await marker.exists()) {
      final existing = (await marker.readAsString()).trim();
      if (_isInstallationId(existing)) return existing;
    }
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final created = base64Url.encode(bytes).replaceAll('=', '');
    await marker.writeAsString(created, flush: true);
    return created;
  }
}

bool _isInstallationId(String value) =>
    value.length == 32 &&
    value.codeUnits.every(
      (code) =>
          (code >= 48 && code <= 57) ||
          (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122) ||
          code == 45 ||
          code == 95,
    );

class OnboardingDraftStore {
  OnboardingDraftStore({
    required this.storage,
    required this.installation,
    required this.now,
    this.ttl = const Duration(days: 7),
  });

  static const storageKey = 'onboarding-draft:v2';
  static const _schemaVersion = 2;

  final ProtectedStorage storage;
  final InstallationBinding installation;
  final DateTime Function() now;
  final Duration ttl;

  Future<void> save(OnboardingDraft draft) async {
    final writtenAt = now().toUtc();
    draft.validatePersisted(today: writtenAt);
    await storage.write(
      storageKey,
      jsonEncode({
        'schema_version': _schemaVersion,
        'installation_id': await installation.currentId(),
        'written_at': writtenAt.toIso8601String(),
        'expires_at': writtenAt.add(ttl).toIso8601String(),
        'draft': draft.toJson(),
      }),
    );
  }

  Future<DraftReadResult> read() async {
    try {
      final encoded = (await storage.readAll())[storageKey];
      if (encoded == null) return const DraftReadResult(DraftReadStatus.empty);
      try {
        final envelope = jsonDecode(encoded) as Map<String, dynamic>;
        if (envelope['schema_version'] != _schemaVersion) {
          await _deleteBestEffort();
          return const DraftReadResult(DraftReadStatus.corrupted);
        }
        final installationId = await installation.currentId();
        if (envelope['installation_id'] != installationId) {
          await _deleteBestEffort();
          return const DraftReadResult(DraftReadStatus.orphaned);
        }
        final expiresAt = DateTime.parse(envelope['expires_at'] as String)
            .toUtc();
        if (!now().toUtc().isBefore(expiresAt)) {
          await _deleteBestEffort();
          return const DraftReadResult(DraftReadStatus.expired);
        }
        return DraftReadResult(
          DraftReadStatus.available,
          OnboardingDraft.fromJson(
            envelope['draft'] as Map<String, dynamic>,
            today: now().toUtc(),
          ),
        );
      } on ProtectedStorageLocked {
        rethrow;
      } on ProtectedStorageUndecryptable {
        rethrow;
      } on Object {
        await _deleteBestEffort();
        return const DraftReadResult(DraftReadStatus.corrupted);
      }
    } on ProtectedStorageLocked {
      return const DraftReadResult(DraftReadStatus.locked);
    } on ProtectedStorageUndecryptable {
      return const DraftReadResult(DraftReadStatus.undecryptable);
    }
  }

  Future<void> clear() => storage.delete(storageKey);

  Future<void> _deleteBestEffort() async {
    try {
      await storage.delete(storageKey);
    } on Object {
      // The unsafe envelope stays inaccessible and will be re-evaluated later.
    }
  }
}
