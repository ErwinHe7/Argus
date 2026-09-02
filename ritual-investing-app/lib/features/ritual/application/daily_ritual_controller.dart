// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/daily_ritual_cache_record.dart';
import '../data/daily_ritual_repository.dart';
import '../domain/daily_ritual.dart';

export '../../../core/api/view_state.dart' show LoadPhase;

enum _AuthorityMerge { accepted, obsolete, contradiction }

@immutable
class DailyRitualEvidenceSnapshotLoad {
  DailyRitualEvidenceSnapshotLoad({
    required this.phase,
    List<RitualEvidenceDetail> details = const [],
  }) : details = List.unmodifiable(details);

  final LoadPhase phase;
  final List<RitualEvidenceDetail> details;
}

class DailyRitualController extends ChangeNotifier {
  DailyRitualController({required DailyRitualRepository repository})
    : _repository = repository;

  final DailyRitualRepository _repository;
  ViewState<DailyRitual> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<List<RitualEvidenceDetail>> _evidenceState = const ViewState(
    phase: LoadPhase.idle,
  );
  ViewState<RitualHistoryPage> _historyState = const ViewState(
    phase: LoadPhase.idle,
  );
  RitualMutationPhase _mutationPhase = RitualMutationPhase.idle;
  final Map<
    (RitualOperation, RitualAssignmentLineage),
    Future<RitualTransitionResult?>
  >
  _activeTransitions = {};
  Future<void> _authorityQueue = Future<void>.value();
  int _readGeneration = 0;
  int _historyRequestId = 0;
  int _evidenceRequestId = 0;
  bool _mutationAuthorityEnabled = true;
  int _lineageSwitches = 0;

  ViewState<DailyRitual> get state => _state;
  ViewState<List<RitualEvidenceDetail>> get evidenceState => _evidenceState;
  ViewState<RitualHistoryPage> get historyState => _historyState;
  RitualMutationPhase get mutationPhase => _mutationPhase;
  bool get mutationAuthorityEnabled => _mutationAuthorityEnabled;

  @visibleForTesting
  int get lineageSwitches => _lineageSwitches;

  @visibleForTesting
  Future<void> get authorityIdle => _authorityQueue;

  Future<void> load() async {
    final generation = ++_readGeneration;
    final prior = _state.value;
    _set(
      ViewState(
        phase: prior == null ? LoadPhase.loading : LoadPhase.stale,
        value: prior,
        committedAt: _state.committedAt,
      ),
    );

    if (_repository.hasScopedAuthority) {
      final cached = await _repository.readCached();
      if (generation != _readGeneration) return;
      if (cached != null) {
        final merge = _mergeAuthority(cached.value, allowLineageSwitch: true);
        if (merge == _AuthorityMerge.accepted) {
          _set(
            ViewState(
              phase: LoadPhase.stale,
              value: _state.value,
              committedAt: cached.committedAt,
            ),
          );
        }
        unawaited(
          _enqueueAuthorityRead(
            generation,
            retainUsablePriorOnRetryableFailure: true,
          ),
        );
        return;
      }
      await _enqueueAuthorityRead(generation);
      return;
    }

    try {
      final result = await _repository.load();
      if (generation != _readGeneration) return;
      final merge = _mergeAuthority(result.value, allowLineageSwitch: true);
      if (merge == _AuthorityMerge.accepted) {
        await _repository.writeAuthority(result.value);
        _set(
          ViewState(
            phase: result.isStale ? LoadPhase.stale : LoadPhase.ready,
            value: _state.value,
            committedAt: result.committedAt,
          ),
        );
      }
    } on Object catch (error) {
      if (generation == _readGeneration) _setReadFailure(error, prior);
    }
  }

  Future<void> revalidate() {
    final generation = ++_readGeneration;
    final prior = _state.value;
    _set(
      ViewState(
        phase: prior == null ? LoadPhase.loading : LoadPhase.stale,
        value: prior,
        committedAt: _state.committedAt,
      ),
    );
    return _enqueueAuthorityRead(generation);
  }

  void invalidateForResume() {
    _repository.forceColdRevalidation();
    _readGeneration += 1;
    _mutationAuthorityEnabled = false;
  }

  bool updateMode(DailyRitualMode mode) {
    if (_repository.effectiveMode == mode) return false;
    _repository.updateMode(mode);
    _readGeneration += 1;
    _evidenceRequestId += 1;
    _state = const ViewState(phase: LoadPhase.idle);
    _evidenceState = const ViewState(phase: LoadPhase.idle);
    _mutationPhase = RitualMutationPhase.idle;
    _mutationAuthorityEnabled = mode != DailyRitualMode.unknown;
    notifyListeners();
    return true;
  }

  Future<void> loadEvidence({DailyRitual? assignment}) async {
    final ritual = assignment ?? _state.value;
    if (ritual == null) return;
    final lineage = ritual.lineage;
    final requestId = ++_evidenceRequestId;
    _evidenceState = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadEvidence(ritual.assignmentId);
      if (requestId != _evidenceRequestId || _state.value?.lineage != lineage) {
        return;
      }
      _evidenceState = ViewState(
        phase: value.isEmpty ? LoadPhase.empty : LoadPhase.ready,
        value: value,
      );
    } on OfflineException {
      if (requestId != _evidenceRequestId) return;
      _evidenceState = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      if (requestId != _evidenceRequestId) return;
      _evidenceState = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  /// Loads detail for one immutable completed-assignment snapshot.
  ///
  /// The result is deliberately detached from [evidenceState], so an open
  /// sheet never starts rendering a newer assignment. Any authority-read
  /// generation or lineage change invalidates the response before delivery.
  Future<DailyRitualEvidenceSnapshotLoad> loadEvidenceSnapshot(
    DailyRitual assignment,
  ) async {
    final lineage = assignment.lineage;
    final generation = _readGeneration;
    if (_state.value?.lineage != lineage) {
      return DailyRitualEvidenceSnapshotLoad(phase: LoadPhase.conflict);
    }
    try {
      final details = await _repository.loadEvidence(assignment.assignmentId);
      if (generation != _readGeneration || _state.value?.lineage != lineage) {
        return DailyRitualEvidenceSnapshotLoad(phase: LoadPhase.conflict);
      }
      return DailyRitualEvidenceSnapshotLoad(
        phase: details.isEmpty ? LoadPhase.empty : LoadPhase.ready,
        details: details,
      );
    } on OfflineException {
      return DailyRitualEvidenceSnapshotLoad(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      return DailyRitualEvidenceSnapshotLoad(phase: failure.phase);
    } on Object {
      return DailyRitualEvidenceSnapshotLoad(phase: LoadPhase.terminalFailure);
    }
  }

  Future<void> loadHistory() async {
    final requestId = ++_historyRequestId;
    _historyState = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadHistory();
      if (requestId != _historyRequestId) return;
      _historyState = ViewState(
        phase: value.items.isEmpty ? LoadPhase.empty : LoadPhase.ready,
        value: value,
      );
    } on OfflineException {
      if (requestId != _historyRequestId) return;
      _historyState = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      if (requestId != _historyRequestId) return;
      _historyState = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<RitualTransitionResult?> reveal({bool refreshHistory = true}) =>
      _runTransition(
        operation: RitualOperation.reveal,
        target: DailyRitualState.revealed,
        allowed: (value) => value.state == DailyRitualState.assigned,
        action: _repository.reveal,
        refreshHistory: refreshHistory,
      );

  Future<RitualTransitionResult?> complete({bool refreshHistory = true}) =>
      _runTransition(
        operation: RitualOperation.complete,
        target: DailyRitualState.completed,
        allowed: (value) => value.state == DailyRitualState.revealed,
        action: _repository.complete,
        refreshHistory: refreshHistory,
      );

  Future<RitualTransitionResult?> _runTransition({
    required RitualOperation operation,
    required DailyRitualState target,
    required bool Function(DailyRitual) allowed,
    required Future<RitualTransitionResult> Function(DailyRitual) action,
    required bool refreshHistory,
  }) {
    final current = _state.value;
    if (current == null || !_mutationAuthorityEnabled || !allowed(current)) {
      return Future.value();
    }
    final key = (operation, current.lineage);
    final active = _activeTransitions[key];
    if (active != null) return active;
    late final Future<RitualTransitionResult?> future;
    future = _performTransition(current, action, refreshHistory: refreshHistory)
        .whenComplete(() {
          if (identical(_activeTransitions[key], future)) {
            _activeTransitions.remove(key);
          }
        });
    _activeTransitions[key] = future;
    return future;
  }

  Future<RitualTransitionResult> _performTransition(
    DailyRitual current,
    Future<RitualTransitionResult> Function(DailyRitual) action, {
    required bool refreshHistory,
  }) async {
    _mutationPhase = RitualMutationPhase.committing;
    notifyListeners();
    final result = await action(current);
    final authoritative = result.authoritative;
    final stillVisibleLineage = _state.value?.hasSameLineage(current) == true;
    if (authoritative != null) {
      final merge = _mergeAuthority(
        authoritative,
        allowLineageSwitch: false,
        expectedLineage: current,
      );
      if (merge == _AuthorityMerge.accepted) {
        await _repository.writeAuthority(authoritative);
        _set(ViewState(phase: LoadPhase.ready, value: _state.value));
      } else if (merge == _AuthorityMerge.contradiction) {
        _handleContradiction();
      }
    }
    if (stillVisibleLineage) {
      _mutationPhase = switch (result.disposition) {
        RitualOperationDisposition.committed => RitualMutationPhase.committed,
        RitualOperationDisposition.reconciledToTarget =>
          RitualMutationPhase.reconciled,
        RitualOperationDisposition.provenNotReached =>
          result.failurePhase == LoadPhase.forbidden ||
                  result.failurePhase == LoadPhase.terminalFailure
              ? RitualMutationPhase.terminalFailure
              : RitualMutationPhase.retryableFailure,
        RitualOperationDisposition.authorityUnavailable =>
          RitualMutationPhase.retryableFailure,
      };
      if (result.disposition ==
          RitualOperationDisposition.authorityUnavailable) {
        _mutationAuthorityEnabled = false;
        _repository.forceColdRevalidation();
      }
      notifyListeners();
    }
    if (refreshHistory) unawaited(loadHistory());
    return result;
  }

  Future<void> _enqueueAuthorityRead(
    int generation, {
    bool retainUsablePriorOnRetryableFailure = false,
  }) {
    final scheduled = _authorityQueue.then(
      (_) => _refreshAuthority(
        generation,
        retainUsablePriorOnRetryableFailure:
            retainUsablePriorOnRetryableFailure,
      ),
    );
    _authorityQueue = scheduled.catchError((Object _) {});
    return scheduled;
  }

  Future<void> _refreshAuthority(
    int generation, {
    required bool retainUsablePriorOnRetryableFailure,
  }) async {
    final prior = _state.value;
    try {
      final result = await _repository.refreshAuthority();
      if (generation != _readGeneration) return;
      final merge = _mergeAuthority(result.value, allowLineageSwitch: true);
      if (merge == _AuthorityMerge.accepted) {
        await _repository.writeAuthority(result.value);
        if (generation != _readGeneration) return;
        _mutationAuthorityEnabled = true;
        _set(
          ViewState(
            phase: LoadPhase.ready,
            value: _state.value,
            committedAt: result.committedAt,
          ),
        );
      } else if (merge == _AuthorityMerge.contradiction) {
        _handleContradiction();
      } else {
        _mutationAuthorityEnabled = true;
        _set(
          ViewState(
            phase: LoadPhase.ready,
            value: _state.value,
            committedAt: _state.committedAt,
          ),
        );
      }
    } on Object catch (error) {
      if (generation == _readGeneration) {
        _setReadFailure(
          error,
          prior,
          preserveUsableAuthority:
              retainUsablePriorOnRetryableFailure &&
              _isRetryableReadFailure(error),
        );
      }
    }
  }

  _AuthorityMerge _mergeAuthority(
    DailyRitual incoming, {
    required bool allowLineageSwitch,
    DailyRitual? expectedLineage,
  }) {
    final current = _state.value;
    if (current == null) {
      if (!allowLineageSwitch &&
          expectedLineage?.hasSameLineage(incoming) != true) {
        return _AuthorityMerge.obsolete;
      }
      _state = ViewState(phase: _state.phase, value: incoming);
      return _AuthorityMerge.accepted;
    }
    if (!current.hasSameLineage(incoming)) {
      if (!allowLineageSwitch) return _AuthorityMerge.obsolete;
      _lineageSwitches += 1;
      _evidenceRequestId += 1;
      _evidenceState = const ViewState(phase: LoadPhase.idle);
      _state = ViewState(phase: _state.phase, value: incoming);
      return _AuthorityMerge.accepted;
    }
    if (incoming.version < current.version ||
        dailyRitualStateRank(incoming.state) <
            dailyRitualStateRank(current.state)) {
      return _AuthorityMerge.obsolete;
    }
    if (!current.hasSameImmutableContent(incoming) ||
        (_repository.hasScopedAuthority &&
            incoming.version == current.version &&
            !current.hasSameVersionPayload(incoming))) {
      return _AuthorityMerge.contradiction;
    }
    if (current.lineage != incoming.lineage) {
      _evidenceRequestId += 1;
      _evidenceState = const ViewState(phase: LoadPhase.idle);
    }
    _state = ViewState(phase: _state.phase, value: incoming);
    return _AuthorityMerge.accepted;
  }

  void _handleContradiction() {
    _mutationAuthorityEnabled = false;
    _repository.forceColdRevalidation();
    _set(
      ViewState(
        phase: LoadPhase.conflict,
        value: _state.value,
        committedAt: _state.committedAt,
      ),
    );
  }

  void _setReadFailure(
    Object error,
    DailyRitual? prior, {
    bool preserveUsableAuthority = false,
  }) {
    if (preserveUsableAuthority && (_state.value ?? prior) != null) {
      _mutationAuthorityEnabled = true;
      _set(
        ViewState(
          phase: LoadPhase.stale,
          value: _state.value ?? prior,
          committedAt: _state.committedAt,
        ),
      );
      return;
    }
    final phase = switch (error) {
      OfflineException() => LoadPhase.retryableFailure,
      LoadFailure failure => failure.phase,
      RitualAuthorityInvalid() => LoadPhase.terminalFailure,
      _ => LoadPhase.terminalFailure,
    };
    _mutationAuthorityEnabled = false;
    _set(
      ViewState(
        phase: phase,
        value: _state.value ?? prior,
        committedAt: _state.committedAt,
      ),
    );
  }

  bool _isRetryableReadFailure(Object error) =>
      error is OfflineException ||
      (error is LoadFailure &&
          (error.phase == LoadPhase.retryableFailure ||
              error.phase == LoadPhase.throttled));

  void _set(ViewState<DailyRitual> value) {
    _state = value;
    notifyListeners();
  }
}
