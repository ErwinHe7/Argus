// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class CircleListController extends ChangeNotifier {
  CircleListController({
    required CircleRepository repository,
    required String Function() createKey,
  }) : _repository = repository,
       _createKey = createKey;

  final CircleRepository _repository;
  final String Function() _createKey;
  ViewState<CircleCollection> _state = const ViewState(phase: LoadPhase.idle);
  CircleMutationPhase _mutationPhase = CircleMutationPhase.idle;
  String? _pendingCommandKey;
  Future<PrivateCircle> Function(String key)? _pendingAction;
  PrivateCircle? _lastCreated;
  Future<void>? _mutationOperation;
  String? _validationMessage;

  ViewState<CircleCollection> get state => _state;
  CircleMutationPhase get mutationPhase => _mutationPhase;
  String? get pendingCommandKey => _pendingCommandKey;
  PrivateCircle? get lastCreated => _lastCreated;
  String? get validationMessage => _validationMessage;

  Future<void> load({bool includeArchived = true}) async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadList(
        includeArchived: includeArchived,
      );
      _state = ViewState(
        phase: value.isStale
            ? LoadPhase.stale
            : (value.value.items.isEmpty ? LoadPhase.empty : LoadPhase.ready),
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

  Future<void> create({
    required String title,
    String description = '',
    List<CircleAsset> assets = const [],
  }) {
    final active = _mutationOperation;
    if (active != null) return active;
    final validation = _validateCircleInput(
      title: title,
      description: description,
      assets: assets,
    );
    if (validation != null) {
      _validationMessage = validation;
      notifyListeners();
      return Future.value();
    }
    _validationMessage = null;
    _pendingCommandKey = _createKey();
    _pendingAction = (key) => _repository.create(
      CircleCreateCommand(
        idempotencyKey: key,
        title: title,
        description: description,
        assets: assets,
      ),
    );
    return retryPending();
  }

  Future<void> copyTemplate(String templateId, {String? title}) {
    final active = _mutationOperation;
    if (active != null) return active;
    if (title != null && (title.trim().isEmpty || title.trim().length > 80)) {
      _validationMessage = title.trim().isEmpty
          ? 'Give your private Circle a title.'
          : 'Circle titles can be up to 80 characters.';
      notifyListeners();
      return Future.value();
    }
    _validationMessage = null;
    _pendingCommandKey = _createKey();
    _pendingAction = (key) => _repository.copy(
      CircleCopyCommand(
        idempotencyKey: key,
        templateId: templateId,
        title: title,
      ),
    );
    return retryPending();
  }

  Future<void> retryPending() {
    final active = _mutationOperation;
    if (active != null) return active;
    final operation = _runPending();
    _mutationOperation = operation;
    return operation.whenComplete(() {
      if (identical(_mutationOperation, operation)) _mutationOperation = null;
    });
  }

  Future<void> _runPending() async {
    final action = _pendingAction;
    final key = _pendingCommandKey;
    if (action == null || key == null) return;
    _mutationPhase = CircleMutationPhase.committing;
    notifyListeners();
    try {
      _lastCreated = await action(key);
      _mutationPhase = CircleMutationPhase.committed;
    } on CircleAmbiguousMutation {
      _mutationPhase = CircleMutationPhase.retryableFailure;
    } on OfflineException {
      _mutationPhase = CircleMutationPhase.retryableFailure;
    } on LoadFailure catch (failure) {
      _mutationPhase = failure.phase == LoadPhase.conflict
          ? CircleMutationPhase.conflictReview
          : (failure.phase == LoadPhase.retryableFailure
                ? CircleMutationPhase.retryableFailure
                : CircleMutationPhase.terminalFailure);
    }
    notifyListeners();
  }
}

enum _ConflictOperation { details, assets, putAsset, removeAsset, archive }

class CircleDetailController extends ChangeNotifier {
  CircleDetailController({
    required this.circleId,
    required CircleRepository repository,
  }) : _repository = repository;

  final String circleId;
  final CircleRepository _repository;
  ViewState<PrivateCircle> _state = const ViewState(phase: LoadPhase.idle);
  CircleDraft _draft = CircleDraft(
    title: '',
    description: '',
    assets: const [],
  );
  bool _requiresConflictReview = false;
  _ConflictOperation? _conflictOperation;
  CircleAsset? _pendingAsset;
  String? _pendingRemovedAssetId;
  String? _validationMessage;
  Future<void>? _mutationOperation;

  ViewState<PrivateCircle> get state => _state;
  CircleDraft get draft => _draft;
  bool get requiresConflictReview => _requiresConflictReview;
  bool get hasPendingConflictResolution => _conflictOperation != null;
  bool get isMutating => _mutationOperation != null;
  String? get validationMessage => _validationMessage;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadDetail(circleId);
      _state = ViewState(
        phase: value.isStale ? LoadPhase.stale : LoadPhase.ready,
        value: value.value,
        committedAt: value.committedAt,
      );
      _draft = CircleDraft.fromCircle(value.value);
    } on OfflineException {
      _state = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }

  void updateDraft({String? title, String? description}) {
    _draft = _draft.copyWith(title: title, description: description);
    notifyListeners();
  }

  void reorderDraft(List<String> assetIds) {
    final existing = {for (final asset in _draft.assets) asset.assetId: asset};
    _draft = _draft.copyWith(
      assets: [
        for (final (index, id) in assetIds.indexed)
          existing[id]!.copyWith(ordinal: index + 1),
      ],
    );
    notifyListeners();
  }

  Future<void> retryLoad() async {
    final operation = _conflictOperation;
    final current = _state.value;
    if (operation == null || current == null) {
      await load();
      return;
    }
    _state = ViewState(phase: LoadPhase.loading, value: current);
    notifyListeners();
    await _loadConflictAuthority(operation, current);
    notifyListeners();
  }

  Future<void> saveDraft() =>
      _runMutation(() => _commit(_ConflictOperation.details));

  Future<void> saveAssetOrder() =>
      _runMutation(() => _commit(_ConflictOperation.assets));

  Future<void> _runMutation(Future<void> Function() action) {
    final active = _mutationOperation;
    if (active != null) return active;
    final operation = action();
    _mutationOperation = operation;
    notifyListeners();
    return operation.whenComplete(() {
      if (identical(_mutationOperation, operation)) {
        _mutationOperation = null;
        notifyListeners();
      }
    });
  }

  Future<void> _commit(_ConflictOperation operation) async {
    final current = _state.value;
    if (current == null || current.isArchived) return;
    final validation = _validateCircleInput(
      title: _draft.title,
      description: _draft.description,
      assets: _draft.assets,
      validateCollectionWeights: operation == _ConflictOperation.assets,
    );
    if (validation != null) {
      _validationMessage = validation;
      notifyListeners();
      return;
    }
    _validationMessage = null;
    _state = ViewState(phase: LoadPhase.loading, value: current);
    notifyListeners();
    try {
      final value = switch (operation) {
        _ConflictOperation.details => await _repository.patch(current, _draft),
        _ConflictOperation.assets => await _repository.replaceAssets(
          current,
          _draft.assets,
        ),
        _ => throw StateError('Unsupported Circle commit operation.'),
      };
      _state = ViewState(phase: LoadPhase.ready, value: value);
      _draft = CircleDraft.fromCircle(value);
      _requiresConflictReview = false;
      _conflictOperation = null;
    } on LoadFailure catch (failure) {
      await _handleMutationFailure(failure, current, operation);
    } on OfflineException {
      _state = ViewState(phase: LoadPhase.retryableFailure, value: current);
    }
    notifyListeners();
  }

  Future<void> reviewAndRetry() => _runMutation(_reviewAndRetry);

  Future<void> _reviewAndRetry() async {
    final operation = _conflictOperation;
    if (!_requiresConflictReview || operation == null) return;
    _requiresConflictReview = false;
    _state = ViewState(phase: LoadPhase.ready, value: _state.value);
    notifyListeners();
    switch (operation) {
      case _ConflictOperation.details:
      case _ConflictOperation.assets:
        await _commit(operation);
        break;
      case _ConflictOperation.putAsset:
        final asset = _pendingAsset;
        if (asset != null) await _putAsset(asset);
        break;
      case _ConflictOperation.removeAsset:
        final assetId = _pendingRemovedAssetId;
        if (assetId != null) await _removeAsset(assetId);
        break;
      case _ConflictOperation.archive:
        await _archive();
        break;
    }
  }

  void useAuthoritativeVersion() {
    final current = _state.value;
    if (current == null) return;
    _draft = CircleDraft.fromCircle(current);
    _requiresConflictReview = false;
    _conflictOperation = null;
    _state = ViewState(phase: LoadPhase.ready, value: current);
    notifyListeners();
  }

  Future<void> putAsset(CircleAsset asset) =>
      _runMutation(() => _putAsset(asset));

  Future<void> _putAsset(CircleAsset asset) async {
    final current = _state.value;
    if (current == null || current.isArchived) return;
    final validation = _validateAsset(asset);
    if (validation != null) {
      _validationMessage = validation;
      notifyListeners();
      return;
    }
    final existing = _draft.assets.any(
      (value) => value.assetId == asset.assetId,
    );
    final candidate = [
      for (final value in _draft.assets)
        if (value.assetId == asset.assetId) asset else value,
      if (!existing) asset,
    ];
    final collectionValidation = _validateAssetMembership(candidate);
    if (collectionValidation != null) {
      _validationMessage = collectionValidation;
      notifyListeners();
      return;
    }
    _validationMessage = null;
    _pendingAsset = asset;
    _state = ViewState(phase: LoadPhase.loading, value: current);
    notifyListeners();
    try {
      final value = await _repository.putAsset(current, asset);
      _applyCommitted(value);
    } on LoadFailure catch (failure) {
      await _handleMutationFailure(
        failure,
        current,
        _ConflictOperation.putAsset,
      );
    } on OfflineException {
      _state = ViewState(phase: LoadPhase.retryableFailure, value: current);
    }
    notifyListeners();
  }

  Future<void> removeAsset(String assetId) =>
      _runMutation(() => _removeAsset(assetId));

  Future<void> _removeAsset(String assetId) async {
    final current = _state.value;
    if (current == null || current.isArchived) return;
    _validationMessage = null;
    _pendingRemovedAssetId = assetId;
    _state = ViewState(phase: LoadPhase.loading, value: current);
    notifyListeners();
    try {
      final value = await _repository.removeAsset(current, assetId);
      _applyCommitted(value);
    } on LoadFailure catch (failure) {
      await _handleMutationFailure(
        failure,
        current,
        _ConflictOperation.removeAsset,
      );
    } on OfflineException {
      _state = ViewState(phase: LoadPhase.retryableFailure, value: current);
    }
    notifyListeners();
  }

  void _applyCommitted(PrivateCircle value) {
    _state = ViewState(phase: LoadPhase.ready, value: value);
    _draft = CircleDraft.fromCircle(value);
    _requiresConflictReview = false;
    _conflictOperation = null;
    _pendingAsset = null;
    _pendingRemovedAssetId = null;
  }

  Future<void> _handleMutationFailure(
    LoadFailure failure,
    PrivateCircle current,
    _ConflictOperation operation,
  ) async {
    if (failure.phase == LoadPhase.conflict) {
      await _loadConflictAuthority(operation, current);
    } else {
      _state = ViewState(phase: failure.phase, value: current);
    }
  }

  Future<void> _loadConflictAuthority(
    _ConflictOperation operation,
    PrivateCircle current,
  ) async {
    _conflictOperation = operation;
    _requiresConflictReview = false;
    try {
      final authoritative = await _repository.fetchCurrent(circleId);
      _state = ViewState(phase: LoadPhase.conflict, value: authoritative);
      _requiresConflictReview = true;
    } on OfflineException {
      _state = ViewState(phase: LoadPhase.retryableFailure, value: current);
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase, value: current);
    }
  }

  Future<void> archive() => _runMutation(_archive);

  Future<void> _archive() async {
    final current = _state.value;
    if (current == null || current.isArchived) return;
    _state = ViewState(phase: LoadPhase.loading, value: current);
    notifyListeners();
    try {
      final value = await _repository.archive(current);
      _state = ViewState(phase: LoadPhase.ready, value: value);
      _draft = CircleDraft.fromCircle(value);
      _requiresConflictReview = false;
      _conflictOperation = null;
    } on LoadFailure catch (failure) {
      await _handleMutationFailure(
        failure,
        current,
        _ConflictOperation.archive,
      );
    } on OfflineException {
      _state = ViewState(phase: LoadPhase.retryableFailure, value: current);
    }
    notifyListeners();
  }
}

String? _validateCircleInput({
  required String title,
  required String description,
  required List<CircleAsset> assets,
  bool validateCollectionWeights = true,
}) {
  final normalizedTitle = title.trim();
  if (normalizedTitle.isEmpty) return 'Give your private Circle a title.';
  if (normalizedTitle.length > 80) {
    return 'Circle titles can be up to 80 characters.';
  }
  if (description.length > 10000) {
    return 'Circle descriptions can be up to 10,000 characters.';
  }
  final membershipValidation = _validateAssetMembership(assets);
  if (membershipValidation != null) return membershipValidation;
  if (validateCollectionWeights) {
    final weighted = assets.where((asset) => asset.weightBps != null).toList();
    if (weighted.isNotEmpty &&
        (weighted.length != assets.length ||
            weighted.fold<int>(0, (sum, asset) => sum + asset.weightBps!) !=
                10000)) {
      return 'Add every weight and make the total 100%.';
    }
  }
  return null;
}

String? _validateAssetMembership(List<CircleAsset> assets) {
  if (assets.length > 50) return 'A Circle can contain up to 50 assets.';
  final ids = <String>{};
  final ordinals = <int>{};
  for (final asset in assets) {
    final validation = _validateAsset(asset);
    if (validation != null) return validation;
    if (!ids.add(asset.assetId)) return 'Each asset can appear only once.';
    if (!ordinals.add(asset.ordinal)) {
      return 'Each asset needs a unique position.';
    }
  }
  return null;
}

String? _validateAsset(CircleAsset asset) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(asset.assetId)) {
    return 'Choose a valid Asset Codex item.';
  }
  if (asset.ordinal < 1 || asset.ordinal > 50) {
    return 'Asset positions must be from 1 to 50.';
  }
  if (asset.note != null && asset.note!.length > 2000) {
    return 'Asset notes can be up to 2,000 characters.';
  }
  final weight = asset.weightBps;
  if (weight != null && (weight < 0 || weight > 10000)) {
    return 'Weight must be from 0% to 100%.';
  }
  return null;
}

class CircleTemplateController extends ChangeNotifier {
  CircleTemplateController({
    required this.templateId,
    required CircleRepository repository,
  }) : _repository = repository;

  final String templateId;
  final CircleRepository _repository;
  ViewState<CircleTemplateDetail> _state = const ViewState(
    phase: LoadPhase.idle,
  );
  CircleTemplateSavePhase _savePhase = CircleTemplateSavePhase.idle;
  Future<void>? _saveOperation;

  ViewState<CircleTemplateDetail> get state => _state;
  CircleTemplateSavePhase get savePhase => _savePhase;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.loadTemplate(templateId);
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

  Future<void> _setSaved(CircleTemplateDetail current, bool target) async {
    _savePhase = CircleTemplateSavePhase.saving;
    notifyListeners();
    try {
      final result = await _repository.setTemplateSaved(current, target);
      _state = ViewState(phase: LoadPhase.ready, value: result.value);
      _savePhase = result.reconciled
          ? CircleTemplateSavePhase.reconciled
          : CircleTemplateSavePhase.saved;
    } on OfflineException {
      _savePhase = CircleTemplateSavePhase.retryableFailure;
    } on LoadFailure catch (failure) {
      _savePhase = failure.phase == LoadPhase.retryableFailure
          ? CircleTemplateSavePhase.retryableFailure
          : CircleTemplateSavePhase.terminalFailure;
    }
    notifyListeners();
  }
}
