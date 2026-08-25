// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class FundingSourceController extends ChangeNotifier {
  FundingSourceController({
    required FundingRepository repository,
    required String Function() createKey,
  }) : _repository = repository,
       _createKey = createKey;

  final FundingRepository _repository;
  final String Function() _createKey;
  ViewState<FundingCollection> _state = const ViewState(phase: LoadPhase.idle);
  String? _message;
  FundingFixture? _pendingFixture;
  String? _pendingCreateKey;
  Future<void>? _mutationOperation;

  ViewState<FundingCollection> get state => _state;
  String? get message => _message;
  FundingFixture? get pendingFixture => _pendingFixture;
  bool get isMutating => _mutationOperation != null;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final result = await _repository.loadSources();
      _state = ViewState(
        phase: result.isStale
            ? LoadPhase.stale
            : (result.value.items.isEmpty ? LoadPhase.empty : LoadPhase.ready),
        value: result.value,
        committedAt: result.committedAt,
      );
    } on OfflineException {
      _state = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    } on FundingFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<void> create(FundingFixture fixture) {
    final active = _mutationOperation;
    if (active != null) return active;
    if (_pendingFixture != null) {
      _message = 'Retry or discard the pending fictional source before adding another.';
      notifyListeners();
      return Future.value();
    }
    _pendingFixture = fixture;
    _pendingCreateKey = _createKey();
    return retryPendingCreate();
  }

  void discardPendingCreate() {
    if (_mutationOperation != null) return;
    _pendingFixture = null;
    _pendingCreateKey = null;
    _message = null;
    notifyListeners();
  }

  Future<void> retryPendingCreate() => _runMutation(() async {
    final fixture = _pendingFixture;
    final key = _pendingCreateKey;
    if (fixture == null || key == null) return;
    _message = null;
    try {
      await _repository.createSource(fixture: fixture, idempotencyKey: key);
      _pendingFixture = null;
      _pendingCreateKey = null;
      await load();
    } on OfflineException {
      _state = ViewState(
        phase: LoadPhase.retryableFailure,
        value: _state.value,
      );
      _message = 'The response is uncertain. Retry this same fictional source command or discard it.';
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase, value: _state.value);
      _message = failure.message ?? 'The fictional source command was not accepted. Review before retrying.';
    } on FundingFailure catch (failure) {
      _state = ViewState(phase: failure.phase, value: _state.value);
      _message = 'The fictional source command could not be completed.';
    }
    notifyListeners();
  });

  Future<void> delete(String sourceId) => _runMutation(() async {
    _message = null;
    try {
      await _repository.deleteSource(sourceId);
      await load();
    } on FundingFailure catch (failure) {
      _state = ViewState(phase: failure.phase, value: _state.value);
      if (failure.reason == FundingFailureReason.fundingSourceInUse) {
        _message = 'The server kept this fictional source active because an active recurring plan uses it.';
      }
    } on OfflineException {
      _state = ViewState(
        phase: LoadPhase.retryableFailure,
        value: _state.value,
      );
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase, value: _state.value);
    }
    notifyListeners();
  });

  Future<void> _runMutation(Future<void> Function() action) {
    final active = _mutationOperation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = action().whenComplete(() {
      if (identical(_mutationOperation, operation)) {
        _mutationOperation = null;
        notifyListeners();
      }
    });
    _mutationOperation = operation;
    notifyListeners();
    return operation;
  }
}
