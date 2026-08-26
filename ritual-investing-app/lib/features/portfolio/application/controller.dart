// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class PortfolioController extends ChangeNotifier {
  PortfolioController({
    required PortfolioRepository repository,
    required this.bootstrapDefaultPortfolioId,
    required String Function() createKey,
  }) : _repository = repository,
       _createKey = createKey;

  final PortfolioRepository _repository;
  final String bootstrapDefaultPortfolioId;
  final String Function() _createKey;
  ViewState<PortfolioCollection> _state = const ViewState(
    phase: LoadPhase.idle,
  );
  ViewState<PortfolioDetail> _detailState = const ViewState(
    phase: LoadPhase.idle,
  );
  String? _selectedPortfolioId;
  String? _pendingName;
  String? _pendingCreateName;
  String? _pendingCreateKey;
  String? _message;
  bool _requiresConflictReview = false;
  bool _requiresArchiveReview = false;
  Future<void>? _mutationOperation;

  ViewState<PortfolioCollection> get state => _state;
  ViewState<PortfolioDetail> get detailState => _detailState;
  String? get selectedPortfolioId => _selectedPortfolioId;
  PortfolioSummary? get selected => _selectedPortfolioId == null
      ? null
      : _state.value?.byId(_selectedPortfolioId!);
  String? get pendingName => _pendingName;
  String? get pendingCreateName => _pendingCreateName;
  String? get message => _message;
  bool get requiresConflictReview => _requiresConflictReview;
  bool get requiresArchiveReview => _requiresArchiveReview;
  bool get isMutating => _mutationOperation != null;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final result = await _repository.loadList();
      final items = result.value.items;
      final bootstrapDefault = result.value.byId(bootstrapDefaultPortfolioId);
      _selectedPortfolioId =
          bootstrapDefault?.id ??
          result.value.serverDefault?.id ??
          (items.isEmpty ? null : items.first.id);
      _state = ViewState(
        phase: result.isStale
            ? LoadPhase.stale
            : (items.isEmpty ? LoadPhase.empty : LoadPhase.ready),
        value: result.value,
        committedAt: result.committedAt,
      );
    } on OfflineException {
      _state = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<void> open(String portfolioId) async {
    _selectedPortfolioId = portfolioId;
    _detailState = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    await _loadDetail(portfolioId);
  }

  Future<void> refreshSelected() async {
    final id = _selectedPortfolioId;
    await load();
    if (id != null) {
      _selectedPortfolioId = id;
      await _loadDetail(id);
    }
  }

  Future<bool> refreshPortfolio(String portfolioId) async {
    _selectedPortfolioId = portfolioId;
    await load();
    if (_state.phase != LoadPhase.ready) return false;
    _selectedPortfolioId = portfolioId;
    await _loadDetail(portfolioId);
    return _detailState.phase == LoadPhase.ready;
  }

  Future<void> _loadDetail(String portfolioId) async {
    try {
      final result = await _repository.loadDetail(portfolioId);
      _detailState = ViewState(
        phase: result.isStale ? LoadPhase.stale : LoadPhase.ready,
        value: result.value,
        committedAt: result.committedAt,
      );
    } on OfflineException {
      _detailState = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _detailState = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  Future<void> create(String name) {
    final active = _mutationOperation;
    if (active != null) return active;
    if (_pendingCreateName != null) {
      _message = 'Retry or discard the pending Demo portfolio before starting another.';
      notifyListeners();
      return Future.value();
    }
    final validation = _validateName(name);
    if (validation != null) {
      _message = validation;
      notifyListeners();
      return Future.value();
    }
    _pendingCreateName = name.trim();
    _pendingCreateKey = _createKey();
    return retryPendingCreate();
  }

  void discardPendingCreate() {
    if (_mutationOperation != null) return;
    _pendingCreateName = null;
    _pendingCreateKey = null;
    _message = null;
    notifyListeners();
  }

  Future<void> retryPendingCreate() => _runMutation(() async {
    final name = _pendingCreateName;
    final key = _pendingCreateKey;
    if (name == null || key == null) return;
    _message = null;
    try {
      final created = await _repository.create(name: name, idempotencyKey: key);
      await load();
      _selectedPortfolioId = created.id;
      _pendingCreateName = null;
      _pendingCreateKey = null;
    } on PortfolioAmbiguousMutation {
      _state = ViewState(
        phase: LoadPhase.retryableFailure,
        value: _state.value,
      );
      _message = 'The response was lost. Retry this unchanged portfolio with the same command key.';
    } on OfflineException {
      _state = ViewState(
        phase: LoadPhase.retryableFailure,
        value: _state.value,
      );
      _message = 'The Demo service is offline. Retry this unchanged portfolio when connected.';
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase, value: _state.value);
      _message = failure.phase == LoadPhase.conflict
          ? 'The server rejected this portfolio command. Review before retrying.'
          : 'This Demo portfolio could not be created.';
    }
    notifyListeners();
  });

  Future<void> renameSelected(String name) =>
      _runMutation(() => _renameSelected(name));

  Future<void> _renameSelected(String name) async {
    final current = _detailState.value?.portfolio ?? selected;
    if (current == null) return;
    final validation = _validateName(name);
    if (validation != null) {
      _message = validation;
      notifyListeners();
      return;
    }
    _pendingName = name.trim();
    _message = null;
    try {
      final updated = await _repository.rename(
        portfolioId: current.id,
        name: _pendingName!,
        expectedVersion: current.version,
      );
      await refreshSelected();
      _selectedPortfolioId = updated.id;
      _pendingName = null;
      _requiresConflictReview = false;
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.conflict) {
        final reconciled = await _loadConflictAuthority(current.id);
        if (reconciled) {
          _requiresConflictReview = true;
          _message = 'The portfolio changed on the server. Review your name and confirm again.';
        }
      } else {
        _detailState = ViewState(
          phase: failure.phase,
          value: _detailState.value,
        );
      }
      _message ??= failure.message;
    } on OfflineException {
      _requiresConflictReview = false;
      _detailState = ViewState(
        phase: LoadPhase.retryableFailure,
        value: _detailState.value,
      );
      _message = 'Reconnect and refresh the authoritative portfolio before reviewing this name.';
    }
    notifyListeners();
  }

  Future<void> reviewAndRetryRename() {
    final name = _pendingName;
    if (!_requiresConflictReview || name == null) return Future.value();
    _requiresConflictReview = false;
    return _runMutation(() => _renameSelected(name));
  }

  Future<void> refreshRenameAuthority() async {
    final portfolioId = _selectedPortfolioId;
    if (_pendingName == null || portfolioId == null) return;
    final reconciled = await _loadConflictAuthority(portfolioId);
    _requiresConflictReview = reconciled;
    if (reconciled) {
      _message = 'The current server name is loaded. Review your draft before retrying.';
    }
    notifyListeners();
  }

  Future<void> archiveSelected() => _runMutation(() async {
    final current = _detailState.value?.portfolio ?? selected;
    if (current == null) return;
    try {
      await _repository.archive(
        portfolioId: current.id,
        expectedVersion: current.version,
      );
      await load();
      _detailState = const ViewState(phase: LoadPhase.idle);
      _message = null;
      _requiresArchiveReview = false;
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.conflict) {
        final reconciled = await _loadConflictAuthority(current.id);
        if (reconciled) {
          _message = failure.message ?? 'The server kept this portfolio active because it is your default or supports an active recurring plan.';
        }
      } else {
        _detailState = ViewState(
          phase: failure.phase,
          value: _detailState.value,
        );
        _message = failure.message;
      }
      _requiresArchiveReview = false;
    } on OfflineException {
      await _reconcileArchive(current.id);
    }
    notifyListeners();
  });

  Future<void> reviewAndRetryArchive() {
    if (!_requiresArchiveReview) return Future.value();
    _requiresArchiveReview = false;
    return archiveSelected();
  }

  Future<void> _reconcileArchive(String portfolioId) async {
    await load();
    if (_state.phase != LoadPhase.ready) {
      _requiresArchiveReview = false;
      _detailState = ViewState(
        phase: LoadPhase.retryableFailure,
        value: _detailState.value,
      );
      _message =
          'Reconnect to reconcile whether the Demo portfolio was archived.';
      return;
    }
    final authority = _state.value?.byId(portfolioId);
    if (authority == null || authority.status == PortfolioStatus.archived) {
      _requiresArchiveReview = false;
      _detailState = const ViewState(phase: LoadPhase.idle);
      _message = 'The server confirms this Demo portfolio is archived.';
      return;
    }
    _selectedPortfolioId = portfolioId;
    await _loadDetail(portfolioId);
    _requiresArchiveReview = _detailState.phase == LoadPhase.ready;
    _message = _requiresArchiveReview
        ? 'The server still shows this portfolio active. Review before trying archive again.'
        : 'Refresh the authoritative portfolio before reviewing archive again.';
  }

  Future<bool> _loadConflictAuthority(String portfolioId) async {
    final prior = _detailState.value;
    try {
      final result = await _repository.loadDetail(portfolioId);
      _detailState = ViewState(
        phase: LoadPhase.conflict,
        value: result.value,
        committedAt: result.committedAt,
      );
      return true;
    } on OfflineException {
      _detailState = ViewState(phase: LoadPhase.retryableFailure, value: prior);
      _message = 'Reconnect to refresh the server portfolio before reviewing this change.';
      return false;
    } on LoadFailure catch (failure) {
      _detailState = ViewState(phase: failure.phase, value: prior);
      _message = 'The current server portfolio could not be refreshed.';
      return false;
    }
  }

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

String? _validateName(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty) return 'Give this Demo portfolio a name.';
  if (normalized.length > 80) {
    return 'Portfolio names can be up to 80 characters.';
  }
  return null;
}
