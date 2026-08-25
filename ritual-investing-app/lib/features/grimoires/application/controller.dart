// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class GrimoireController extends ChangeNotifier {
  GrimoireController({
    required this.grimoireId,
    required GrimoireRepository repository,
  }) : _repository = repository;

  final String grimoireId;
  final GrimoireRepository _repository;
  ViewState<GrimoireDetail> _state = const ViewState(phase: LoadPhase.idle);
  GrimoireSavePhase _savePhase = GrimoireSavePhase.idle;
  Future<void>? _saveOperation;

  ViewState<GrimoireDetail> get state => _state;
  GrimoireSavePhase get savePhase => _savePhase;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.load(grimoireId);
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

  Future<void> _setSaved(GrimoireDetail current, bool target) async {
    _savePhase = GrimoireSavePhase.saving;
    notifyListeners();
    try {
      final result = await _repository.setSaved(current, target);
      _state = ViewState(phase: LoadPhase.ready, value: result.value);
      _savePhase = result.reconciled
          ? GrimoireSavePhase.reconciled
          : GrimoireSavePhase.saved;
    } on OfflineException {
      _savePhase = GrimoireSavePhase.retryableFailure;
    } on LoadFailure catch (failure) {
      _savePhase = failure.phase == LoadPhase.retryableFailure
          ? GrimoireSavePhase.retryableFailure
          : GrimoireSavePhase.terminalFailure;
    }
    notifyListeners();
  }
}
