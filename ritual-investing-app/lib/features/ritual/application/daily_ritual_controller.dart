// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/daily_ritual_repository.dart';
import '../domain/daily_ritual.dart';

export '../../../core/api/view_state.dart' show LoadPhase;

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
  Future<void>? _activeTransition;

  ViewState<DailyRitual> get state => _state;
  ViewState<List<RitualEvidenceDetail>> get evidenceState => _evidenceState;
  ViewState<RitualHistoryPage> get historyState => _historyState;
  RitualMutationPhase get mutationPhase => _mutationPhase;

  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      _set(
        ViewState(
          phase: result.isStale ? LoadPhase.stale : LoadPhase.ready,
          value: result.value,
          committedAt: result.committedAt,
        ),
      );
    } on OfflineException {
      _set(const ViewState(phase: LoadPhase.retryableFailure));
    } on LoadFailure catch (failure) {
      _set(ViewState(phase: failure.phase));
    }
  }

  Future<void> loadEvidence() async {
    final ritual = _state.value;
    if (ritual == null) return;
    _evidenceState = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadEvidence(ritual.assignmentId);
      _evidenceState = ViewState(
        phase: value.isEmpty ? LoadPhase.empty : LoadPhase.ready,
        value: value,
      );
    } on OfflineException {
      _evidenceState = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _evidenceState = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _historyState = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadHistory();
      _historyState = ViewState(
        phase: value.items.isEmpty ? LoadPhase.empty : LoadPhase.ready,
        value: value,
      );
    } on OfflineException {
      _historyState = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _historyState = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<void> reveal() => _runTransition(
    allowed: (value) => value.state == DailyRitualState.assigned,
    action: _repository.reveal,
  );

  Future<void> complete() => _runTransition(
    allowed: (value) => value.state == DailyRitualState.revealed,
    action: _repository.complete,
  );

  Future<void> _runTransition({
    required bool Function(DailyRitual) allowed,
    required Future<RitualTransitionResult> Function(DailyRitual) action,
  }) {
    final active = _activeTransition;
    if (active != null) return active;
    final current = _state.value;
    if (current == null || !allowed(current)) return Future.value();
    final future = _performTransition(current, action);
    _activeTransition = future;
    return future.whenComplete(() {
      if (identical(_activeTransition, future)) _activeTransition = null;
    });
  }

  Future<void> _performTransition(
    DailyRitual current,
    Future<RitualTransitionResult> Function(DailyRitual) action,
  ) async {
    _mutationPhase = RitualMutationPhase.committing;
    notifyListeners();
    try {
      final result = await action(current);
      _set(ViewState(phase: LoadPhase.ready, value: result.value));
      _mutationPhase = result.reconciled
          ? RitualMutationPhase.reconciled
          : RitualMutationPhase.committed;
      await loadHistory();
    } on OfflineException {
      _mutationPhase = RitualMutationPhase.retryableFailure;
      notifyListeners();
    } on LoadFailure catch (failure) {
      _mutationPhase = switch (failure.phase) {
        LoadPhase.retryableFailure ||
        LoadPhase.conflict => RitualMutationPhase.retryableFailure,
        _ => RitualMutationPhase.terminalFailure,
      };
      notifyListeners();
    }
  }

  void _set(ViewState<DailyRitual> value) {
    _state = value;
    notifyListeners();
  }
}
