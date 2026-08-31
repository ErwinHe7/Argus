// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../data/starpath_repository.dart';
import '../domain/starpath.dart';

enum StarpathViewPhase {
  idle,
  loading,
  ready,
  cachedStale,
  offlineReadOnly,
  conflictReloading,
  unavailable,
  forbidden,
  failure,
}

@immutable
class StarpathViewState {
  const StarpathViewState({
    required this.phase,
    this.snapshot,
    this.committedAt,
    this.rowanNodeOrdinal,
    this.reconciled = false,
  });

  final StarpathViewPhase phase;
  final StarpathSnapshot? snapshot;
  final DateTime? committedAt;
  final int? rowanNodeOrdinal;
  final bool reconciled;

  bool get isReadOnly =>
      phase == StarpathViewPhase.cachedStale ||
      phase == StarpathViewPhase.offlineReadOnly ||
      (snapshot?.isDraftPreview ?? false);
}

class StarpathController extends ChangeNotifier {
  StarpathController({
    required StarpathRepository repository,
    required String Function() createKey,
  }) : _repository = repository,
       _createKey = createKey;

  final StarpathRepository _repository;
  final String Function() _createKey;
  StarpathViewState _state = const StarpathViewState(
    phase: StarpathViewPhase.idle,
  );
  String? _pendingStartKey;
  String? _pendingAnswerKey;
  String? _pendingAnswerIdentity;
  String? _pendingRecallSkipKey;
  Future<void>? _activeCommand;

  StarpathViewState get state => _state;

  Future<void> load() async {
    _set(
      StarpathViewState(
        phase: StarpathViewPhase.loading,
        snapshot: _state.snapshot,
      ),
    );
    try {
      final result = await _repository.load();
      _set(
        StarpathViewState(
          phase: result.isStale
              ? StarpathViewPhase.cachedStale
              : StarpathViewPhase.ready,
          snapshot: result.value,
          committedAt: result.committedAt,
        ),
      );
    } on Object catch (error) {
      if (error is OfflineException) {
        _set(
          StarpathViewState(
            phase: StarpathViewPhase.offlineReadOnly,
            snapshot: _state.snapshot,
          ),
        );
      } else if (error is StarpathForbidden) {
        _set(const StarpathViewState(phase: StarpathViewPhase.forbidden));
      } else if (error is StarpathUnavailable ||
          error is StarpathUnsupportedContract) {
        _set(const StarpathViewState(phase: StarpathViewPhase.unavailable));
      } else {
        _set(const StarpathViewState(phase: StarpathViewPhase.failure));
      }
    }
  }

  Future<void> start() {
    if (_state.phase == StarpathViewPhase.cachedStale ||
        _state.phase == StarpathViewPhase.loading) {
      return Future.value();
    }
    _pendingStartKey ??= _createKey();
    return _run(() async {
      try {
        final result = await _repository.start(_pendingStartKey!);
        _pendingStartKey = null;
        _replace(result);
      } on Object catch (error) {
        if (error is OfflineException || error is StarpathAmbiguousCommand) {
          _set(
            StarpathViewState(
              phase: StarpathViewPhase.offlineReadOnly,
              snapshot: _state.snapshot,
            ),
          );
        } else if (error is StarpathForbidden) {
          _set(const StarpathViewState(phase: StarpathViewPhase.forbidden));
        } else if (error is StarpathUnavailable ||
            error is StarpathUnsupportedContract) {
          _clearUnavailable();
        } else {
          _set(
            StarpathViewState(
              phase: StarpathViewPhase.failure,
              snapshot: _state.snapshot,
            ),
          );
        }
      }
    });
  }

  Future<void> answer(String optionId) {
    final current = _state.snapshot;
    if (current == null || _state.isReadOnly) return Future.value();
    final command = _answerCommand(current, optionId);
    if (command == null) return Future.value();
    if (_pendingAnswerIdentity != command.identity) {
      _pendingAnswerIdentity = command.identity;
      _pendingAnswerKey = _createKey();
    }
    return _run(() async {
      try {
        final result = await _repository.answer(
          current: current,
          idempotencyKey: _pendingAnswerKey!,
          command: command,
        );
        _pendingAnswerIdentity = null;
        _pendingAnswerKey = null;
        _replace(result);
      } on Object catch (error) {
        if (error is StarpathConflict) {
          await _reloadConflict();
        } else if (error is OfflineException ||
            error is StarpathAmbiguousCommand) {
          _set(
            StarpathViewState(
              phase: StarpathViewPhase.offlineReadOnly,
              snapshot: current,
            ),
          );
        } else if (error is StarpathForbidden) {
          _set(const StarpathViewState(phase: StarpathViewPhase.forbidden));
        } else if (error is StarpathUnavailable ||
            error is StarpathUnsupportedContract) {
          _clearUnavailable();
        } else {
          _set(
            StarpathViewState(
              phase: StarpathViewPhase.failure,
              snapshot: current,
            ),
          );
        }
      }
    });
  }

  Future<void> skipRecall() {
    final current = _state.snapshot;
    if (current == null || current.recall == null || _state.isReadOnly) {
      return Future.value();
    }
    _pendingRecallSkipKey ??= _createKey();
    return _run(() async {
      try {
        final result = await _repository.skipRecall(
          current: current,
          idempotencyKey: _pendingRecallSkipKey!,
        );
        _pendingRecallSkipKey = null;
        _replace(result);
      } on Object catch (error) {
        if (error is StarpathConflict) {
          await _reloadConflict();
        } else if (error is OfflineException ||
            error is StarpathAmbiguousCommand) {
          _set(
            StarpathViewState(
              phase: StarpathViewPhase.offlineReadOnly,
              snapshot: current,
            ),
          );
        } else if (error is StarpathUnavailable ||
            error is StarpathUnsupportedContract) {
          _clearUnavailable();
        } else {
          _set(
            StarpathViewState(
              phase: StarpathViewPhase.failure,
              snapshot: current,
            ),
          );
        }
      }
    });
  }

  void revealRowan(int nodeOrdinal) {
    final snapshot = _state.snapshot;
    if (snapshot == null ||
        !snapshot.nodes.any((node) => node.nodeOrdinal == nodeOrdinal)) {
      return;
    }
    _set(
      StarpathViewState(
        phase: _state.phase,
        snapshot: snapshot,
        committedAt: _state.committedAt,
        rowanNodeOrdinal: nodeOrdinal,
        reconciled: _state.reconciled,
      ),
    );
  }

  void dismissRowan() {
    if (_state.rowanNodeOrdinal == null) return;
    _set(
      StarpathViewState(
        phase: _state.phase,
        snapshot: _state.snapshot,
        committedAt: _state.committedAt,
        reconciled: _state.reconciled,
      ),
    );
  }

  StarpathAnswerCommand? _answerCommand(
    StarpathSnapshot snapshot,
    String optionId,
  ) {
    final session = snapshot.session;
    if (session == null || session.state != StarpathSessionState.active) {
      return null;
    }
    final recall = snapshot.recall;
    if (recall != null) {
      if (!recall.knowledgeCheck.options.any((item) => item.id == optionId)) {
        return null;
      }
      return StarpathAnswerCommand(
        attemptKind: StarpathAttemptKind.recall,
        sessionId: session.id,
        manifestId: snapshot.authority.manifestId,
        revisionId: recall.revisionId,
        questionId: recall.questionId,
        optionId: optionId,
      );
    }
    final node = snapshot.currentNode;
    if (node == null ||
        !node.knowledgeCheck.options.any((item) => item.id == optionId)) {
      return null;
    }
    return StarpathAnswerCommand(
      attemptKind: StarpathAttemptKind.node,
      sessionId: session.id,
      manifestId: snapshot.authority.manifestId,
      revisionId: node.revisionId,
      questionId: node.knowledgeCheck.id,
      optionId: optionId,
    );
  }

  Future<void> _reloadConflict() async {
    _set(
      StarpathViewState(
        phase: StarpathViewPhase.conflictReloading,
        snapshot: _state.snapshot,
      ),
    );
    await load();
  }

  void _replace(StarpathMutationResult result) {
    if (result.conflicted) {
      _set(
        StarpathViewState(
          phase: StarpathViewPhase.conflictReloading,
          snapshot: _state.snapshot,
        ),
      );
    }
    _set(
      StarpathViewState(
        phase: StarpathViewPhase.ready,
        snapshot: result.snapshot,
        reconciled: result.reconciled,
      ),
    );
  }

  void _clearUnavailable() {
    _pendingAnswerIdentity = null;
    _pendingAnswerKey = null;
    _pendingRecallSkipKey = null;
    _set(const StarpathViewState(phase: StarpathViewPhase.unavailable));
  }

  Future<void> _run(Future<void> Function() command) {
    final active = _activeCommand;
    if (active != null) return active;
    final future = command();
    _activeCommand = future;
    return future.whenComplete(() {
      if (identical(_activeCommand, future)) _activeCommand = null;
    });
  }

  void _set(StarpathViewState value) {
    _state = value;
    notifyListeners();
  }
}
