// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum RecurringCommandPhase {
  idle,
  loading,
  empty,
  listReady,
  detailReady,
  createReview,
  editReview,
  confirming,
  restoredReview,
  reconciliationRequired,
  retryableFailure,
  conflictReview,
  forbidden,
  throttled,
  terminalFailure,
}

class RecurringPlanController extends ChangeNotifier {
  RecurringPlanController({
    required RecurringPlanRepository repository,
    required PendingCommandStore pendingStore,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
    required MemberContributionRhythm rhythm,
    required Future<bool> Function(String sourceId) isFundingSourceActive,
  }) : _repository = repository,
       _now = now,
       _isFundingSourceActive = isFundingSourceActive,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       ),
       _defaults = _defaultsFor(rhythm);

  RecurringDefaults _defaults;

  RecurringDefaults get defaults => _defaults;

  void updateRhythm(MemberContributionRhythm rhythm) {
    final next = _defaultsFor(rhythm);
    if (_defaults.frequency == next.frequency &&
        _defaults.label == next.label) {
      return;
    }
    _defaults = next;
    notifyListeners();
  }

  static RecurringDefaults _defaultsFor(MemberContributionRhythm rhythm) =>
      switch (rhythm) {
        MemberContributionRhythm.weekly => const RecurringDefaults(
          frequency: RecurringFrequency.weekly,
          label: 'Weekly rhythm suggested · editable before review',
        ),
        MemberContributionRhythm.biweekly => const RecurringDefaults(
          frequency: RecurringFrequency.weekly,
          label: 'Every-two-weeks preference · editable weekly suggestion',
        ),
        MemberContributionRhythm.monthly => const RecurringDefaults(
          frequency: RecurringFrequency.monthly,
          label: 'Monthly rhythm suggested · editable before review',
        ),
        _ => const RecurringDefaults(
          frequency: RecurringFrequency.monthly,
          label: 'Flexible monthly suggestion · editable before review',
        ),
      };

  final RecurringPlanRepository _repository;
  final CacheScope scope;
  final DateTime Function() _now;
  final Future<bool> Function(String sourceId) _isFundingSourceActive;
  final FinancialCommandJournal _journal;
  String? _portfolioId;
  RecurringCommandPhase _phase = RecurringCommandPhase.idle;
  List<RecurringPlan> _plans = const [];
  RecurringPlan? _selected;
  RecurringPlanDraft? _createDraft;
  RecurringEditDraft? _editDraft;
  JournaledFinancialCommand? _protectedCreate;
  String? _lastCreatedSourceId;
  String? _message;
  Future<void>? _mutationOperation;

  RecurringCommandPhase get phase => _phase;
  List<RecurringPlan> get plans => _plans;
  RecurringPlan? get selected => _selected;
  RecurringPlanDraft? get createDraft => _createDraft;
  RecurringEditDraft? get editDraft => _editDraft;
  String? get lastCreatedSourceId => _lastCreatedSourceId;
  String? get message => _message;
  bool get isMutating => _mutationOperation != null;
  String get operation => 'recurring.create:${_portfolioId ?? 'unselected'}';

  Future<void> openPortfolio(String portfolioId) async {
    if (_portfolioId != portfolioId) {
      _portfolioId = portfolioId;
      _plans = const [];
      _selected = null;
      _createDraft = null;
      _editDraft = null;
      _protectedCreate = null;
      _lastCreatedSourceId = null;
      _phase = RecurringCommandPhase.loading;
      _message = null;
      notifyListeners();
    }
    final reconciled = await _refreshList();
    final restored = await _journal.restore(operation);
    if (restored == null) return;
    try {
      final draft = RecurringPlanDraft.fromProtectedMap(restored.precondition);
      if (draft.portfolioId != portfolioId) throw const FormatException();
      _protectedCreate = restored;
      _createDraft = draft;
      final sourceActive = await _isFundingSourceActive(draft.sourceId);
      _phase = reconciled && sourceActive
          ? RecurringCommandPhase.restoredReview
          : RecurringCommandPhase.reconciliationRequired;
      _message = reconciled && sourceActive
          ? 'A saved Demo plan may have been created. Review the exact saved cadence and amount before a same-key retry.'
          : 'Refresh authoritative plans before reviewing the saved command.';
    } on Object {
      await _journal.clear(operation);
      _protectedCreate = null;
      _createDraft = null;
      _phase = RecurringCommandPhase.terminalFailure;
      _message = 'The protected recurring-plan review is not supported. Start a new review.';
    }
    notifyListeners();
  }

  Future<void> openPlan(String planId) async {
    try {
      final value = await _repository.get(planId);
      if (value.portfolioId != _portfolioId) {
        throw const LoadFailure(LoadPhase.forbidden);
      }
      _selected = value;
      _phase = RecurringCommandPhase.detailReady;
      _message = null;
    } on Object catch (error) {
      _mapFailure(error);
    }
    notifyListeners();
  }

  Future<bool> prepareCreate(
    RecurringPlanDraft draft, {
    required bool sourceIsActive,
  }) async {
    if (_mutationOperation != null) return false;
    if (_protectedCreate != null) {
      _message = 'Resolve or explicitly discard the saved plan confirmation before creating another plan.';
      notifyListeners();
      return false;
    }
    final validation = _validateDraft(draft, sourceIsActive: sourceIsActive);
    if (validation != null) {
      _message = validation;
      notifyListeners();
      return false;
    }
    _portfolioId = draft.portfolioId;
    _protectedCreate = null;
    _createDraft = draft;
    _editDraft = null;
    _lastCreatedSourceId = null;
    _phase = RecurringCommandPhase.createReview;
    _message = 'Review the editable Demo schedule. It will never confirm automatically.';
    notifyListeners();
    return true;
  }

  Future<void> discardPendingCreate() async {
    if (_protectedCreate == null ||
        (_phase != RecurringCommandPhase.restoredReview &&
            _phase != RecurringCommandPhase.retryableFailure)) {
      return;
    }
    await _journal.clear(operation);
    _protectedCreate = null;
    _createDraft = null;
    _phase = _plans.isEmpty
        ? RecurringCommandPhase.empty
        : RecurringCommandPhase.listReady;
    _message = 'Saved plan confirmation discarded after explicit review. A new plan will use a new key.';
    notifyListeners();
  }

  void reviewRestoredCreate() {
    if (_phase != RecurringCommandPhase.restoredReview &&
        _phase != RecurringCommandPhase.retryableFailure &&
        _phase != RecurringCommandPhase.throttled) {
      return;
    }
    _phase = RecurringCommandPhase.createReview;
    _message = 'Review the unchanged saved Demo plan before a same-key retry.';
    notifyListeners();
  }

  Future<void> confirmCreate() => _runMutation(() async {
    if (_phase != RecurringCommandPhase.createReview || _createDraft == null) {
      return;
    }
    final draft = _createDraft!;
    final sourceIsActive = await _isFundingSourceActive(draft.sourceId);
    if (!sourceIsActive) {
      _phase = RecurringCommandPhase.reconciliationRequired;
      _message = _protectedCreate == null
          ? 'The selected fictional source is no longer active. Refresh it before confirming this review.'
          : 'The protected fictional source is no longer active. The uncertain command is preserved but cannot be retried.';
      notifyListeners();
      return;
    }
    final payload = draft.toCanonicalMap();
    final existing = _protectedCreate;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _journal.clear(operation);
      _protectedCreate = null;
      _phase = RecurringCommandPhase.conflictReview;
      _message = 'The plan changed. Start and review a new command.';
      return;
    }
    _protectedCreate = await _journal.protect(
      operation: operation,
      payload: payload,
      precondition: payload,
      reuse: existing,
    );
    _phase = RecurringCommandPhase.confirming;
    _message = null;
    notifyListeners();
    try {
      _selected = await _repository.create(
        RecurringPlanCreate(
          draft: draft,
          idempotencyKey: _protectedCreate!.key,
        ),
      );
      _lastCreatedSourceId = draft.sourceId;
      await _journal.clear(operation);
      _protectedCreate = null;
      _createDraft = null;
      await _refreshList();
      _phase = RecurringCommandPhase.detailReady;
      _message = 'Authoritative Demo schedule created. No provider or real money is connected.';
    } on AmbiguousRecurringCreateFailure {
      final reconciled = await _refreshList();
      _phase = reconciled
          ? RecurringCommandPhase.retryableFailure
          : RecurringCommandPhase.reconciliationRequired;
      _message = reconciled
          ? 'The response was lost. Review the exact saved plan before a same-key retry.'
          : 'The response was lost and plan authority is unavailable. Nothing will retry automatically.';
    } on OfflineException {
      _phase = RecurringCommandPhase.reconciliationRequired;
      _message =
          'Plan authority is unavailable. Nothing will retry automatically.';
    } on Object catch (error) {
      _mapFailure(error);
      if (_phase == RecurringCommandPhase.forbidden ||
          _phase == RecurringCommandPhase.conflictReview ||
          _phase == RecurringCommandPhase.terminalFailure) {
        await _journal.clear(operation);
        _protectedCreate = null;
      }
    }
    notifyListeners();
  });

  void prepareEdit({
    int? amountMinor,
    RecurringFrequency? frequency,
    List<RecurringAllocation>? allocations,
  }) {
    if (_mutationOperation != null) return;
    final plan = _selected;
    if (plan == null ||
        plan.status == RecurringStatus.cancelled ||
        plan.status == RecurringStatus.completed) {
      _message = 'Only active or paused Demo plans can be edited.';
      notifyListeners();
      return;
    }
    if (amountMinor == null && frequency == null && allocations == null) {
      _message = 'Change at least one schedule field.';
      notifyListeners();
      return;
    }
    if (amountMinor != null && (amountMinor < 1 || amountMinor > 1000000000)) {
      _message = 'Enter a positive Demo amount within the supported range.';
      notifyListeners();
      return;
    }
    if (allocations != null && _allocationError(allocations) != null) {
      _message = _allocationError(allocations);
      notifyListeners();
      return;
    }
    _editDraft = RecurringEditDraft(
      amountMinor: amountMinor,
      frequency: frequency,
      allocations: allocations,
    );
    _phase = RecurringCommandPhase.editReview;
    _message =
        'Review these changes against authoritative plan v${plan.version}.';
    notifyListeners();
  }

  void reviewEditAgainstAuthority() {
    if (_phase != RecurringCommandPhase.conflictReview || _editDraft == null) {
      return;
    }
    _phase = RecurringCommandPhase.editReview;
    _message =
        'Review the preserved edit against authoritative plan v${_selected?.version}.';
    notifyListeners();
  }

  Future<void> confirmEdit() => _runMutation(() async {
    if (_phase != RecurringCommandPhase.editReview ||
        _selected == null ||
        _editDraft == null) {
      return;
    }
    final baseline = _selected!;
    final draft = _editDraft!;
    _phase = RecurringCommandPhase.confirming;
    notifyListeners();
    try {
      _selected = await _repository.edit(
        RecurringPlanEdit(
          planId: baseline.id,
          expectedVersion: baseline.version,
          amountMinor: draft.amountMinor,
          frequency: draft.frequency,
          allocations: draft.allocations,
        ),
      );
      _editDraft = null;
      await _refreshList();
      _phase = RecurringCommandPhase.detailReady;
      _message = 'The authoritative Demo schedule was updated.';
    } on AmbiguousRecurringMutationFailure {
      await _handleAmbiguousEdit(baseline, draft);
    } on OfflineException {
      await _handleAmbiguousEdit(baseline, draft);
    } on RecurringFailure catch (failure) {
      if (failure.reason == RecurringFailureReason.conflict) {
        final authority = await _reconcilePlan(baseline.id);
        _phase = authority == null
            ? RecurringCommandPhase.reconciliationRequired
            : RecurringCommandPhase.conflictReview;
        _message = authority == null
            ? 'The plan changed and authority is unavailable. Refresh before reviewing the preserved edit.'
            : 'The plan changed on the server. Review the preserved edit against the new version.';
      } else {
        _phase = RecurringCommandPhase.terminalFailure;
        _message = 'The Demo plan rejected this transition.';
      }
    } on Object catch (error) {
      _mapFailure(error);
    }
    notifyListeners();
  });

  Future<void> pause() => _transition(RecurringStatus.paused);
  Future<void> resume() => _transition(RecurringStatus.active);

  Future<void> _transition(RecurringStatus target) => _runMutation(() async {
    final baseline = _selected;
    if (baseline == null) return;
    final valid = target == RecurringStatus.paused
        ? baseline.status == RecurringStatus.active
        : baseline.status == RecurringStatus.paused;
    if (!valid) {
      _phase = RecurringCommandPhase.conflictReview;
      _message = 'Refresh the plan before requesting that transition.';
      notifyListeners();
      return;
    }
    _phase = RecurringCommandPhase.confirming;
    notifyListeners();
    try {
      _selected = target == RecurringStatus.paused
          ? await _repository.pause(baseline.id, baseline.version)
          : await _repository.resume(baseline.id, baseline.version);
      await _refreshList();
      _phase = RecurringCommandPhase.detailReady;
      _message =
          'Authoritative status: ${_selected!.status.name}; next Demo run ${_selected!.nextRunAt.toUtc().toIso8601String()}.';
    } on AmbiguousRecurringMutationFailure {
      await _handleAmbiguousTransition(baseline, target);
    } on OfflineException {
      await _handleAmbiguousTransition(baseline, target);
    } on RecurringFailure {
      final authority = await _reconcilePlan(baseline.id);
      _phase = authority == null
          ? RecurringCommandPhase.reconciliationRequired
          : RecurringCommandPhase.conflictReview;
      _message = authority == null
          ? 'The transition conflicts and plan authority is unavailable. Nothing was repeated.'
          : 'The transition conflicts with current server state. Review the refreshed plan.';
    } on Object catch (error) {
      _mapFailure(error);
    }
    notifyListeners();
  });

  Future<void> cancel() => _runMutation(() async {
    final baseline = _selected;
    if (baseline == null || baseline.status == RecurringStatus.cancelled) {
      return;
    }
    _phase = RecurringCommandPhase.confirming;
    notifyListeners();
    try {
      await _repository.cancel(baseline.id, baseline.version);
      final authority = await _reconcilePlan(baseline.id);
      if (authority?.status != RecurringStatus.cancelled) {
        _phase = RecurringCommandPhase.reconciliationRequired;
        _message = 'Cancellation was accepted, but the authoritative terminal state is still refreshing.';
      } else {
        _phase = RecurringCommandPhase.detailReady;
        _message = 'The Demo plan is authoritatively cancelled.';
      }
    } on AmbiguousRecurringMutationFailure {
      await _handleAmbiguousCancel(baseline);
    } on OfflineException {
      await _handleAmbiguousCancel(baseline);
    } on RecurringFailure {
      final authority = await _reconcilePlan(baseline.id);
      _phase = authority == null
          ? RecurringCommandPhase.reconciliationRequired
          : RecurringCommandPhase.conflictReview;
      _message = authority == null
          ? 'Cancellation conflicts and plan authority is unavailable. Nothing was repeated.'
          : 'Cancellation conflicts with current server state. Review the refreshed plan.';
    } on Object catch (error) {
      _mapFailure(error);
    }
    notifyListeners();
  });

  Future<bool> _refreshList() async {
    final portfolioId = _portfolioId;
    if (portfolioId == null) return false;
    try {
      _plans = List.unmodifiable(await _repository.list(portfolioId));
      if (_protectedCreate == null &&
          _createDraft == null &&
          _editDraft == null) {
        _phase = _plans.isEmpty
            ? RecurringCommandPhase.empty
            : RecurringCommandPhase.listReady;
      }
      notifyListeners();
      return true;
    } on Object catch (error) {
      _mapFailure(error);
      notifyListeners();
      return false;
    }
  }

  Future<RecurringPlan?> _reconcilePlan(String planId) async {
    try {
      final authority = await _repository.get(planId);
      _selected = authority;
      await _refreshList();
      return authority;
    } on Object {
      return null;
    }
  }

  Future<void> _handleAmbiguousEdit(
    RecurringPlan baseline,
    RecurringEditDraft draft,
  ) async {
    final authority = await _reconcilePlan(baseline.id);
    if (authority != null && _editMatches(authority, draft)) {
      _editDraft = null;
      _phase = RecurringCommandPhase.detailReady;
      _message = 'The server confirms the reviewed schedule change.';
    } else {
      _phase = authority == null
          ? RecurringCommandPhase.reconciliationRequired
          : RecurringCommandPhase.conflictReview;
      _message = 'The response was uncertain. Authority was checked; review before any new attempt.';
    }
  }

  Future<void> _handleAmbiguousTransition(
    RecurringPlan baseline,
    RecurringStatus target,
  ) async {
    final authority = await _reconcilePlan(baseline.id);
    if (authority != null &&
        authority.status == target &&
        authority.version > baseline.version) {
      _phase = RecurringCommandPhase.detailReady;
      _message = 'The server confirms the requested ${target.name} state.';
    } else {
      _phase = authority == null
          ? RecurringCommandPhase.reconciliationRequired
          : RecurringCommandPhase.conflictReview;
      _message = 'The response was uncertain. Authority was checked; the transition was not repeated.';
    }
  }

  Future<void> _handleAmbiguousCancel(RecurringPlan baseline) async {
    final authority = await _reconcilePlan(baseline.id);
    if (authority != null &&
        authority.status == RecurringStatus.cancelled &&
        authority.version > baseline.version) {
      _phase = RecurringCommandPhase.detailReady;
      _message = 'The server confirms terminal cancellation.';
    } else {
      _phase = authority == null
          ? RecurringCommandPhase.reconciliationRequired
          : RecurringCommandPhase.conflictReview;
      _message = 'The response was uncertain. Cancellation was not repeated against a newer version.';
    }
  }

  bool _editMatches(RecurringPlan value, RecurringEditDraft draft) {
    if (draft.amountMinor != null && value.amountMinor != draft.amountMinor) {
      return false;
    }
    if (draft.frequency != null && value.frequency != draft.frequency) {
      return false;
    }
    final allocations = draft.allocations;
    if (allocations != null) {
      final actual = {
        for (final item in value.allocations) item.assetId: item.weightBps,
      };
      final expected = {
        for (final item in allocations) item.assetId: item.weightBps,
      };
      if (actual.length != expected.length) return false;
      for (final entry in expected.entries) {
        if (actual[entry.key] != entry.value) {
          return false;
        }
      }
    }
    return true;
  }

  String? _validateDraft(
    RecurringPlanDraft draft, {
    required bool sourceIsActive,
  }) {
    if (!sourceIsActive || draft.sourceId.trim().isEmpty) {
      return 'Choose an active fictional funding source. No credentials are collected.';
    }
    if (draft.amountMinor < 1 || draft.amountMinor > 1000000000) {
      return 'Enter a positive Demo amount within the supported range.';
    }
    if (!draft.firstRunAt.toUtc().isAfter(_now().toUtc())) {
      return 'Choose a future first Demo run.';
    }
    return _allocationError(draft.allocations);
  }

  String? _allocationError(List<RecurringAllocation> allocations) {
    if (allocations.isEmpty || allocations.length > 50) {
      return 'Choose between 1 and 50 Demo allocations.';
    }
    if (allocations.any(
      (item) =>
          item.assetId.trim().isEmpty ||
          item.weightBps < 0 ||
          item.weightBps > 10000,
    )) {
      return 'Every allocation needs a valid asset and weight.';
    }
    if (allocations.map((item) => item.assetId).toSet().length !=
        allocations.length) {
      return 'Each Demo asset can appear only once.';
    }
    if (allocations.fold<int>(0, (sum, item) => sum + item.weightBps) !=
        10000) {
      return 'Demo allocation weights must total 100%.';
    }
    return null;
  }

  void _mapFailure(Object error) {
    if (error is OfflineException ||
        error is AmbiguousRecurringMutationFailure) {
      _phase = RecurringCommandPhase.reconciliationRequired;
      _message = 'Authoritative plan state is unavailable. Nothing will retry automatically.';
      return;
    }
    if (error is LoadFailure) {
      _phase = switch (error.phase) {
        LoadPhase.forbidden => RecurringCommandPhase.forbidden,
        LoadPhase.throttled => RecurringCommandPhase.throttled,
        LoadPhase.conflict => RecurringCommandPhase.conflictReview,
        LoadPhase.retryableFailure => RecurringCommandPhase.retryableFailure,
        _ => RecurringCommandPhase.terminalFailure,
      };
      _message = error.message;
      return;
    }
    if (error is RecurringFailure) {
      _phase = error.reason == RecurringFailureReason.conflict
          ? RecurringCommandPhase.conflictReview
          : RecurringCommandPhase.terminalFailure;
      _message = 'The Demo recurring-plan operation was rejected.';
      return;
    }
    _phase = RecurringCommandPhase.terminalFailure;
    _message =
        'The recurring-plan response is not supported by this app version.';
  }

  Future<void> retryReconciliation() async {
    final portfolioId = _portfolioId;
    if (portfolioId == null) return;
    final listReady = await _refreshList();
    final sourceActive = _createDraft == null
        ? true
        : await _isFundingSourceActive(_createDraft!.sourceId);
    if (listReady && sourceActive) {
      _phase = _protectedCreate != null
          ? RecurringCommandPhase.restoredReview
          : (_editDraft != null
                ? RecurringCommandPhase.conflictReview
                : (_createDraft != null
                      ? RecurringCommandPhase.createReview
                      : RecurringCommandPhase.listReady));
      _message = _protectedCreate != null
          ? 'Authority and the saved fictional source are current. Review before a same-key retry.'
          : 'Authority is current. Review any preserved change before retrying.';
    } else {
      _phase = RecurringCommandPhase.reconciliationRequired;
      _message = sourceActive
          ? 'Authoritative recurring plans are still unavailable.'
          : 'The protected fictional source is no longer active. The uncertain command is preserved but cannot be retried.';
    }
    notifyListeners();
  }

  Future<void> _runMutation(Future<void> Function() action) {
    final current = _mutationOperation;
    if (current != null) return current;
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
