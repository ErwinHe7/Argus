// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class CovenController extends ChangeNotifier {
  CovenController({required CovenRepository repository})
    : _repository = repository;
  final CovenRepository _repository;
  ViewState<CovenModel> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<CovenModel> get state => _state;
  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      _set(
        ViewState(
          phase: result.isStale
              ? LoadPhase.stale
              : (result.value.entries.isEmpty
                    ? LoadPhase.empty
                    : LoadPhase.ready),
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

  void _set(ViewState<CovenModel> value) {
    _state = value;
    notifyListeners();
  }
}

class CovenDetailController extends ChangeNotifier {
  CovenDetailController({
    required this.entryId,
    required CovenRepository repository,
  }) : _repository = repository;

  final String entryId;
  final CovenRepository _repository;
  ViewState<CovenDetail> _state = const ViewState(phase: LoadPhase.idle);
  CovenSavePhase _savePhase = CovenSavePhase.idle;
  Future<void>? _saveOperation;

  ViewState<CovenDetail> get state => _state;
  CovenSavePhase get savePhase => _savePhase;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadDetail(entryId);
      _state = ViewState(
        phase: value.isStale ? LoadPhase.stale : LoadPhase.ready,
        value: value.value,
        committedAt: value.committedAt,
      );
    } on OfflineException {
      _state = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<void> toggleSaved() {
    final active = _saveOperation;
    if (active != null) return active;
    final current = _state.value;
    if (current == null) return Future.value();
    final future = _setSaved(current, !current.saved);
    _saveOperation = future;
    return future.whenComplete(() {
      if (identical(_saveOperation, future)) _saveOperation = null;
    });
  }

  Future<void> _setSaved(CovenDetail current, bool target) async {
    _savePhase = CovenSavePhase.saving;
    notifyListeners();
    try {
      final result = await _repository.setSaved(current, target);
      _state = ViewState(phase: LoadPhase.ready, value: result.value);
      _savePhase = result.reconciled
          ? CovenSavePhase.reconciled
          : CovenSavePhase.saved;
    } on OfflineException {
      _savePhase = CovenSavePhase.retryableFailure;
    } on LoadFailure catch (failure) {
      _savePhase = failure.phase == LoadPhase.retryableFailure
          ? CovenSavePhase.retryableFailure
          : CovenSavePhase.terminalFailure;
    }
    notifyListeners();
  }
}
