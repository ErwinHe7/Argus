// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class AssetCodexController extends ChangeNotifier {
  AssetCodexController({
    required AssetCodexRepository repository,
    required this.assetId,
    required this.source,
  }) : _repository = repository;

  final AssetCodexRepository _repository;
  final String assetId;
  final AssetSourceContext source;
  ViewState<AssetCodex> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<AssetComparison> _comparisonState = const ViewState(
    phase: LoadPhase.idle,
  );
  AssetSavePhase _savePhase = AssetSavePhase.idle;
  Future<void>? _saveOperation;

  ViewState<AssetCodex> get state => _state;
  ViewState<AssetComparison> get comparisonState => _comparisonState;
  AssetSavePhase get savePhase => _savePhase;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.load(assetId, source);
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

  Future<void> _setSaved(AssetCodex current, bool target) async {
    _savePhase = AssetSavePhase.saving;
    notifyListeners();
    try {
      final result = await _repository.setSaved(current, target);
      _state = ViewState(phase: LoadPhase.ready, value: result.value);
      _savePhase = result.reconciled
          ? AssetSavePhase.reconciled
          : AssetSavePhase.saved;
    } on OfflineException {
      _savePhase = AssetSavePhase.retryableFailure;
    } on LoadFailure catch (failure) {
      _savePhase = failure.phase == LoadPhase.retryableFailure
          ? AssetSavePhase.retryableFailure
          : AssetSavePhase.terminalFailure;
    }
    notifyListeners();
  }

  Future<void> compareWith(List<String> peerIds) async {
    final ids = <String>[assetId, ...peerIds.where((id) => id != assetId)];
    if (ids.length < 2 || ids.length > 5) {
      _comparisonState = const ViewState(phase: LoadPhase.terminalFailure);
      notifyListeners();
      return;
    }
    _comparisonState = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.compare(ids);
      _comparisonState = ViewState(phase: LoadPhase.ready, value: value);
    } on OfflineException {
      _comparisonState = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _comparisonState = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }
}
