import 'dart:convert';
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

class ProtectedStorageInstallationBinding implements InstallationBinding {
  ProtectedStorageInstallationBinding({required this.storage, Random? random})
    : _random = random ?? Random.secure();

  static const storageKey = 'onboarding-install:v1';
  final ProtectedStorage storage;
  final Random _random;

  @override
  Future<String> currentId() async {
    final existing = (await storage.readAll())[storageKey];
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final created = base64Url.encode(bytes).replaceAll('=', '');
    await storage.write(storageKey, created);
    return created;
  }
}

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
