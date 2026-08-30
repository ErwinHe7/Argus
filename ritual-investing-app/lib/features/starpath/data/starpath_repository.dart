// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/starpath.dart';

export '../../../core/cache/cached_read.dart'
    show OfflineException, RepositoryRead;

abstract interface class StarpathService {
  Future<StarpathSnapshot> fetch();
  Future<StarpathSnapshot> start({required String idempotencyKey});
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  });
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  });
}

class StarpathAmbiguousCommand implements Exception {
  const StarpathAmbiguousCommand();
}

class StarpathConflict implements Exception {
  const StarpathConflict();
}

class StarpathUnavailable implements Exception {
  const StarpathUnavailable();
}

class StarpathForbidden implements Exception {
  const StarpathForbidden();
}

class StarpathUnsupportedContract implements Exception {
  const StarpathUnsupportedContract();
}

class StarpathMutationResult {
  const StarpathMutationResult({
    required this.snapshot,
    required this.reconciled,
    required this.conflicted,
  });

  final StarpathSnapshot snapshot;
  final bool reconciled;
  final bool conflicted;
}

class StarpathRepository {
  StarpathRepository({
    required StarpathService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final StarpathService _service;
  final ReadCache _cache;

  Future<RepositoryRead<StarpathSnapshot>> load() =>
      cachedRead(key: 'starpath', cache: _cache, fetch: _service.fetch);

  Future<StarpathMutationResult> start(String idempotencyKey) => _mutate(
    reconciledOutcome: (snapshot) =>
        snapshot.availability == StarpathAvailability.available &&
        snapshot.session != null,
    mutate: () => _service.start(idempotencyKey: idempotencyKey),
  );

  Future<StarpathMutationResult> answer({
    required StarpathSnapshot current,
    required String idempotencyKey,
    required StarpathAnswerCommand command,
  }) => _mutate(
    reconciledOutcome: (snapshot) => snapshot.version > current.version,
    mutate: () => _service.answer(
      idempotencyKey: idempotencyKey,
      version: current.version,
      command: command,
    ),
  );

  Future<StarpathMutationResult> skipRecall({
    required StarpathSnapshot current,
    required String idempotencyKey,
  }) {
    final session = current.session;
    if (session == null) throw const StarpathUnavailable();
    return _mutate(
      reconciledOutcome: (snapshot) =>
          snapshot.version > current.version && snapshot.recall == null,
      mutate: () => _service.skipRecall(
        idempotencyKey: idempotencyKey,
        version: current.version,
        sessionId: session.id,
      ),
    );
  }

  Future<StarpathMutationResult> _mutate({
    required bool Function(StarpathSnapshot) reconciledOutcome,
    required Future<StarpathSnapshot> Function() mutate,
  }) async {
    try {
      final snapshot = await mutate();
      await _cache.put('starpath', snapshot, DateTime.now().toUtc());
      return StarpathMutationResult(
        snapshot: snapshot,
        reconciled: false,
        conflicted: false,
      );
    } on Object catch (error) {
      final ambiguous =
          error is StarpathAmbiguousCommand || error is OfflineException;
      final conflicted = error is StarpathConflict;
      if (!ambiguous && !conflicted) rethrow;
      final snapshot = await _service.fetch();
      if (ambiguous && !reconciledOutcome(snapshot)) rethrow;
      await _cache.put('starpath', snapshot, DateTime.now().toUtc());
      return StarpathMutationResult(
        snapshot: snapshot,
        reconciled: true,
        conflicted: conflicted,
      );
    }
  }
}
