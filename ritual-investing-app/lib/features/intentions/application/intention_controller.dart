// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/invalidation_bus.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../onboarding/domain/onboarding_draft.dart';
import '../../profile/domain/model.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum IntentionPhase {
  idle,
  loading,
  empty,
  ready,
  detailReady,
  createReview,
  editReview,
  archiveReview,
  confirming,
  restoredReview,
  reconciliationRequired,
  retryableFailure,
  conflictReview,
  forbidden,
  throttled,
  terminalFailure,
}

class IntentionController extends ChangeNotifier {
  IntentionController({
    required IntentionRepository repository,
    required PendingCommandStore pendingStore,
    required InvalidationBus invalidationBus,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
  }) : _repository = repository,
       _now = now,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       ),
       _defaults = _defaultsFor(null, now().toUtc()) {
    _invalidationSubscription = invalidationBus
        .eventsFor(scope)
        .listen(_handleInvalidation);
  }

  final IntentionRepository _repository;
  final DateTime Function() _now;
  final FinancialCommandJournal _journal;
  final CacheScope scope;
  late final StreamSubscription<InvalidationEvent> _invalidationSubscription;

  IntentionDefaults _defaults;
  IntentionPhase _phase = IntentionPhase.idle;
  List<Intention> _intentions = const [];
  Intention? _selected;
  IntentionDraft? _createDraft;
  IntentionDraft? _editDraft;
  JournaledFinancialCommand? _protectedCreate;
  String? _portfolioId;
  String? _nextCursor;
  bool _hasMore = false;
  bool _isStale = false;
  bool _archivePending = false;
  String? _message;
  Future<void>? _mutation;
  bool _disposed = false;

  IntentionDefaults get defaults => _defaults;
  IntentionPhase get phase => _phase;
  List<Intention> get intentions => List.unmodifiable(_intentions);
  Intention? get selected => _selected;
  IntentionDraft? get createDraft => _createDraft;
  IntentionDraft? get editDraft => _editDraft;
  bool get hasMore => _hasMore;
  bool get isStale => _isStale;
  bool get archivePending => _archivePending;
  bool get isMutating => _mutation != null;
  String? get message => _message;
  String get operation => 'intention.create:${_portfolioId ?? 'unselected'}';

  void updateProfile(SavedInvestorProfile? profile) {
    final next = _defaultsFor(profile, _now().toUtc());
    if (next.title == _defaults.title &&
        next.targetDate == _defaults.targetDate &&
        next.sourceLabel == _defaults.sourceLabel) {
      return;
    }
    _defaults = next;
    notifyListeners();
  }

  IntentionDraft newDraft({required int targetMinor}) {
    final draft = IntentionDraft(
      portfolioId: _portfolioId ?? '',
      title: _defaults.title,
      targetMinor: targetMinor,
      targetDate: _defaults.targetDate,
    );
    _createDraft ??= draft;
    return draft;
  }

  Future<void> openPortfolio(String portfolioId) async {
    if (_portfolioId != portfolioId) {
      _portfolioId = portfolioId;
      _intentions = const [];
      _selected = null;
      _createDraft = null;
      _editDraft = null;
      _protectedCreate = null;
      _archivePending = false;
      _phase = IntentionPhase.loading;
      _message = null;
      notifyListeners();
    }
    final reconciled = await _refresh();
    final restored = await _journal.restore(operation);
    if (restored == null) return;
    try {
      final draft = IntentionDraft.fromProtectedMap(restored.precondition);
      if (draft.portfolioId != portfolioId || !_validDraft(draft)) {
        throw const FormatException();
      }
      _protectedCreate = restored;
      _createDraft = draft;
      final exact = _matchingIntention(draft);
      if (reconciled && exact != null) {
        await _journal.clear(operation);
        _protectedCreate = null;
        _createDraft = null;
        _selected = exact;
        _phase = IntentionPhase.detailReady;
        _message = 'The server confirms the saved Demo Intention was created.';
      } else {
        _phase = reconciled
            ? IntentionPhase.restoredReview
            : IntentionPhase.reconciliationRequired;
        _message = reconciled
            ? 'A saved Intention may not have completed. Review the exact goal before a same-key retry.'
            : 'Authoritative Intentions are unavailable. Nothing will retry automatically.';
      }
    } on Object {
      await _journal.clear(operation);
      _protectedCreate = null;
      _createDraft = null;
      _phase = IntentionPhase.terminalFailure;
      _message = 'The saved Intention review is unsupported. Start again.';
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _nextCursor == null || _portfolioId == null) return;
    try {
      var result = await _repository.load(cursor: _nextCursor);
      var stale = result.isStale;
      final additions = <Intention>[];
      final cursors = <String>{};
      while (true) {
        additions.addAll(
          result.value.items
              .where((item) => item.portfolioId == _portfolioId)
              .where(
                (item) =>
                    !_intentions.any((existing) => existing.id == item.id),
              ),
        );
        final next = result.value.nextCursor;
        if (additions.isNotEmpty ||
            !result.value.hasMore ||
            next == null ||
            !cursors.add(next)) {
          break;
        }
        result = await _repository.load(cursor: next);
        stale = stale || result.isStale;
      }
      _intentions = [..._intentions, ...additions];
      _nextCursor = result.value.nextCursor;
      _hasMore = result.value.hasMore;
      _isStale = stale;
      _phase = _intentions.isEmpty
          ? IntentionPhase.empty
          : IntentionPhase.ready;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
  }

  Future<void> openIntention(String intentionId) async {
    try {
      final result = await _repository.get(intentionId);
      if (result.value.id != intentionId ||
          result.value.portfolioId != _portfolioId) {
        throw const LoadFailure(LoadPhase.forbidden);
      }
      _selected = result.value;
      _isStale = result.isStale;
      _phase = IntentionPhase.detailReady;
      _message = result.isStale
          ? 'Showing cached goal progress until the Demo ledger reconnects.'
          : null;
    } on Object catch (error) {
      _selected = null;
      _mapFailure(error);
    }
    notifyListeners();
  }

  Future<bool> prepareCreate(IntentionDraft draft) async {
    if (_mutation != null) return false;
    if (_protectedCreate != null) {
      _message = 'Resolve the saved Intention before creating another.';
      notifyListeners();
      return false;
    }
    if (draft.portfolioId != _portfolioId || !_validDraft(draft)) {
      _message = _draftError(draft);
      notifyListeners();
      return false;
    }
    _createDraft = draft;
    _editDraft = null;
    _phase = IntentionPhase.createReview;
    _message = 'Review this provider-free Demo goal. Nothing is created automatically.';
    notifyListeners();
    return true;
  }

  void reviewRestoredCreate() {
    if (_phase != IntentionPhase.restoredReview &&
        _phase != IntentionPhase.retryableFailure &&
        _phase != IntentionPhase.throttled) {
      return;
    }
    _phase = IntentionPhase.createReview;
    _message = 'Review the unchanged saved goal before the same-key retry.';
    notifyListeners();
  }

  Future<void> discardPendingCreate() async {
    if (_protectedCreate == null ||
        (_phase != IntentionPhase.restoredReview &&
            _phase != IntentionPhase.retryableFailure &&
            _phase != IntentionPhase.throttled)) {
      return;
    }
    await _journal.clear(operation);
    _protectedCreate = null;
    _createDraft = null;
    _phase = _intentions.isEmpty ? IntentionPhase.empty : IntentionPhase.ready;
    _message = 'Saved Intention recovery discarded after fresh authority and explicit review.';
    notifyListeners();
  }

  Future<void> retryReconciliation() async {
    if (_phase != IntentionPhase.reconciliationRequired) return;
    if (_protectedCreate != null && _createDraft != null) {
      final fresh = await _refresh();
      final exact = _matchingIntention(_createDraft!);
      if (fresh && exact != null) {
        await _journal.clear(operation);
        _protectedCreate = null;
        _createDraft = null;
        _selected = exact;
        _phase = IntentionPhase.detailReady;
        _message = 'The server confirms the saved Demo Intention was created.';
      } else if (fresh) {
        _phase = IntentionPhase.restoredReview;
        _message = 'Authority is current. Review the unchanged saved goal before recovery.';
      } else {
        _phase = IntentionPhase.reconciliationRequired;
        _message = 'Authoritative Intentions are still unavailable. Nothing was submitted.';
      }
      notifyListeners();
      return;
    }
    if (_editDraft != null) {
      await _reconcileEdit(const AmbiguousIntentionMutation());
      notifyListeners();
      return;
    }
    if (_archivePending) {
      await _reconcileArchive(const AmbiguousIntentionMutation());
      notifyListeners();
      return;
    }
    await _refresh();
  }

  Future<void> confirmCreate() => _runMutation(() async {
    final draft = _createDraft;
    if (_phase != IntentionPhase.createReview || draft == null) return;
    final payload = draft.toCanonicalMap();
    final existing = _protectedCreate;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _journal.clear(operation);
      _protectedCreate = null;
      _phase = IntentionPhase.conflictReview;
      _message = 'The goal changed. Start a new reviewed command.';
      return;
    }
    _protectedCreate = await _journal.protect(
      operation: operation,
      payload: payload,
      precondition: payload,
      reuse: existing,
    );
    _phase = IntentionPhase.confirming;
    _message = null;
    notifyListeners();
    try {
      final created = await _repository.create(
        IntentionCreate(draft: draft, idempotencyKey: _protectedCreate!.key),
      );
      _requirePortfolio(created);
      await _journal.clear(operation);
      _protectedCreate = null;
      _createDraft = null;
      _selected = created;
      await _refresh();
      _selected =
          _intentions.where((item) => item.id == created.id).firstOrNull ??
          created;
      _phase = IntentionPhase.detailReady;
      _message = 'Authoritative Demo Intention created. No real money moves.';
    } on AmbiguousIntentionCreate {
      final reconciled = await _refresh();
      final exact = _matchingIntention(draft);
      if (reconciled && exact != null) {
        await _journal.clear(operation);
        _protectedCreate = null;
        _createDraft = null;
        _selected = exact;
        _phase = IntentionPhase.detailReady;
        _message = 'The server confirms the Demo Intention was created.';
      } else {
        _phase = reconciled
            ? IntentionPhase.retryableFailure
            : IntentionPhase.reconciliationRequired;
        _message = reconciled
            ? 'The response was lost. Review the unchanged saved goal before a same-key retry.'
            : 'The response was lost and authority is unavailable. Nothing will retry automatically.';
      }
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
      if (_phase == IntentionPhase.forbidden ||
          _phase == IntentionPhase.terminalFailure ||
          _phase == IntentionPhase.conflictReview) {
        await _journal.clear(operation);
        _protectedCreate = null;
      }
    }
  });

  void prepareEdit(IntentionDraft draft) {
    if (_mutation != null || _selected == null) return;
    if (draft.portfolioId != _portfolioId || !_validDraft(draft)) {
      _message = _draftError(draft);
      notifyListeners();
      return;
    }
    _editDraft = draft;
    _phase = IntentionPhase.editReview;
    _message =
        'Review changes against authoritative goal v${_selected!.version}.';
    notifyListeners();
  }

  void reviewEditAgainstAuthority() {
    if (_phase != IntentionPhase.conflictReview || _editDraft == null) return;
    _phase = IntentionPhase.editReview;
    _message =
        'Review the preserved draft against authoritative goal v${_selected?.version}.';
    notifyListeners();
  }

  Future<void> confirmEdit() => _runMutation(() async {
    final current = _selected;
    final draft = _editDraft;
    if (_phase != IntentionPhase.editReview ||
        current == null ||
        draft == null) {
      return;
    }
    _phase = IntentionPhase.confirming;
    notifyListeners();
    try {
      final updated = await _repository.patch(
        IntentionPatch(
          intentionId: current.id,
          expectedVersion: current.version,
          draft: draft,
        ),
      );
      _requirePortfolio(updated);
      _selected = updated;
      _editDraft = null;
      await _refresh();
      _phase = IntentionPhase.detailReady;
      _message = 'Authoritative Demo Intention updated.';
    } on Object catch (error) {
      if (error is AmbiguousIntentionMutation ||
          (error is LoadFailure && error.phase == LoadPhase.conflict)) {
        await _reconcileEdit(error);
      } else {
        _mapFailure(error, preserveValue: true);
      }
    }
  });

  void prepareArchive() {
    if (_mutation != null || _selected == null) return;
    _archivePending = true;
    _phase = IntentionPhase.archiveReview;
    _message = 'Archiving preserves historical Future Mirror scenarios.';
    notifyListeners();
  }

  void reviewArchiveAgainstAuthority() {
    if (_phase != IntentionPhase.conflictReview || !_archivePending) return;
    _phase = IntentionPhase.archiveReview;
    _message =
        'Review archive against authoritative goal v${_selected?.version}.';
    notifyListeners();
  }

  Future<void> confirmArchive() => _runMutation(() async {
    final current = _selected;
    if (_phase != IntentionPhase.archiveReview || current == null) return;
    _phase = IntentionPhase.confirming;
    notifyListeners();
    try {
      await _repository.archive(current.id, current.version);
      final refreshed = await _repository.get(current.id);
      _requirePortfolio(refreshed.value);
      _selected = refreshed.value;
      await _refresh();
      _archivePending = false;
      _phase = IntentionPhase.detailReady;
      _message =
          'This Demo Intention is archived; its projections remain historical.';
    } on Object catch (error) {
      if (error is AmbiguousIntentionMutation ||
          (error is LoadFailure && error.phase == LoadPhase.conflict)) {
        await _reconcileArchive(error);
      } else {
        _mapFailure(error, preserveValue: true);
      }
    }
  });

  Future<void> _reconcileEdit(Object error) async {
    final current = _selected;
    final draft = _editDraft;
    if (current == null || draft == null) return;
    try {
      final authority = await _repository.get(current.id);
      _requirePortfolio(authority.value);
      _selected = authority.value;
      if (draft.exactlyMatches(authority.value)) {
        _editDraft = null;
        await _refresh();
        _phase = IntentionPhase.detailReady;
        _message = 'The server confirms those Demo goal changes.';
      } else {
        _phase = IntentionPhase.conflictReview;
        _message = 'The goal changed elsewhere. Your draft is preserved for explicit review.';
      }
    } on Object {
      _phase = IntentionPhase.reconciliationRequired;
      _message = 'Goal authority is unavailable. Your draft is preserved and nothing will retry automatically.';
    }
  }

  Future<void> _reconcileArchive(Object error) async {
    final current = _selected;
    if (current == null) return;
    try {
      final authority = await _repository.get(current.id);
      _requirePortfolio(authority.value);
      _selected = authority.value;
      if (authority.value.status == IntentionStatus.archived) {
        await _refresh();
        _archivePending = false;
        _phase = IntentionPhase.detailReady;
        _message = 'The server confirms this Demo Intention is archived.';
      } else {
        _phase = IntentionPhase.conflictReview;
        _message = 'The goal changed elsewhere. Review the latest version before archiving.';
      }
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.empty) {
        _selected = null;
        await _refresh();
        _archivePending = false;
        _message = 'The server confirms this Intention is no longer active.';
      } else {
        _phase = IntentionPhase.reconciliationRequired;
        _message =
            'Goal authority is unavailable. Nothing will retry automatically.';
      }
    } on Object {
      _phase = IntentionPhase.reconciliationRequired;
      _message =
          'Goal authority is unavailable. Nothing will retry automatically.';
    }
  }

  Future<bool> _refresh() async {
    final portfolioId = _portfolioId;
    if (portfolioId == null) return false;
    try {
      var result = await _repository.load();
      var stale = result.isStale;
      final intentions = result.value.items
          .where((item) => item.portfolioId == portfolioId)
          .toList();
      final cursors = <String>{};
      while (intentions.isEmpty &&
          result.value.hasMore &&
          result.value.nextCursor != null &&
          cursors.add(result.value.nextCursor!)) {
        result = await _repository.load(cursor: result.value.nextCursor);
        stale = stale || result.isStale;
        intentions.addAll(
          result.value.items.where((item) => item.portfolioId == portfolioId),
        );
      }
      _intentions = intentions;
      _nextCursor = result.value.nextCursor;
      _hasMore = result.value.hasMore;
      _isStale = stale;
      _phase = _intentions.isEmpty
          ? IntentionPhase.empty
          : IntentionPhase.ready;
      _message = stale
          ? 'Showing cached goal progress until the Demo ledger reconnects.'
          : null;
      if (_selected case final selected?) {
        _selected =
            _intentions.where((item) => item.id == selected.id).firstOrNull ??
            selected;
      }
      notifyListeners();
      return !stale;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
      notifyListeners();
      return false;
    }
  }

  Intention? _matchingIntention(IntentionDraft draft) =>
      _intentions.where(draft.exactlyMatches).singleOrNull;

  void _requirePortfolio(Intention intention) {
    if (intention.portfolioId != _portfolioId) {
      throw const LoadFailure(LoadPhase.forbidden);
    }
  }

  void _handleInvalidation(InvalidationEvent event) {
    if (_disposed ||
        event.resource != InvalidationResource.ledger ||
        _portfolioId == null) {
      return;
    }
    unawaited(_refresh());
  }

  Future<void> _runMutation(Future<void> Function() action) {
    final active = _mutation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = action().whenComplete(() {
      if (identical(_mutation, operation)) {
        _mutation = null;
        if (!_disposed) notifyListeners();
      }
    });
    _mutation = operation;
    notifyListeners();
    return operation;
  }

  void _mapFailure(Object error, {bool preserveValue = false}) {
    final failure = switch (error) {
      OfflineException() => const LoadFailure(LoadPhase.retryableFailure),
      LoadFailure() => error,
      _ => const LoadFailure(LoadPhase.terminalFailure),
    };
    _phase = switch (failure.phase) {
      LoadPhase.forbidden => IntentionPhase.forbidden,
      LoadPhase.conflict => IntentionPhase.conflictReview,
      LoadPhase.throttled => IntentionPhase.throttled,
      LoadPhase.retryableFailure => IntentionPhase.retryableFailure,
      _ => IntentionPhase.terminalFailure,
    };
    if (!preserveValue) _selected = null;
    _message =
        failure.message ??
        switch (_phase) {
          IntentionPhase.retryableFailure =>
            'Intentions are unavailable. Existing source data is preserved.',
          IntentionPhase.throttled =>
            'Goal requests are paused briefly. Review remains available.',
          IntentionPhase.forbidden =>
            'This Intention is not available for this portfolio.',
          IntentionPhase.conflictReview =>
            'The goal changed. Refresh and review before retrying.',
          _ => 'This Demo Intention could not be loaded.',
        };
  }

  bool _validDraft(IntentionDraft draft) {
    final today = _date(_now().toUtc());
    return draft.portfolioId.trim().isNotEmpty &&
        draft.title.trim().isNotEmpty &&
        draft.title.trim().length <= 120 &&
        draft.targetMinor >= 1 &&
        draft.targetMinor <= 1000000000 &&
        draft.status != IntentionStatus.archived &&
        _isDateOnly(draft.targetDate) &&
        draft.targetDate.isAfter(today);
  }

  String _draftError(IntentionDraft draft) {
    if (draft.title.trim().isEmpty || draft.title.trim().length > 120) {
      return 'Enter a goal name between 1 and 120 characters.';
    }
    if (draft.targetMinor < 1 || draft.targetMinor > 1000000000) {
      return 'Enter a positive Demo target within the supported range.';
    }
    return 'Choose a future calendar date for this Demo goal.';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_invalidationSubscription.cancel());
    super.dispose();
  }
}

IntentionDefaults _defaultsFor(SavedInvestorProfile? investor, DateTime now) {
  final goal = investor?.goal;
  final horizon = investor?.horizon;
  final years = switch (horizon) {
    InvestmentHorizon.short => 1,
    InvestmentHorizon.medium => 3,
    InvestmentHorizon.long => 10,
    null => 3,
  };
  final title = switch (goal) {
    InvestmentGoal.calmFund => 'Build a calm fund',
    InvestmentGoal.longTermGrowth => 'Grow for the long term',
    InvestmentGoal.income => 'Explore a Demo income goal',
    InvestmentGoal.exploration => 'Explore a future possibility',
    null => 'Shape a future intention',
  };
  final source = investor == null
      ? 'Editable neutral goal and three-year horizon suggestion'
      : '${investor.goal.label} · ${investor.horizon.label} horizon · editable starting point';
  return IntentionDefaults(
    title: title,
    targetDate: _addYears(_date(now), years),
    sourceLabel: source,
  );
}

DateTime _addYears(DateTime value, int years) {
  final year = value.year + years;
  final maxDay = DateTime.utc(year, value.month + 1, 0).day;
  return DateTime.utc(year, value.month, value.day.clamp(1, maxDay));
}

DateTime _date(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

bool _isDateOnly(DateTime value) =>
    value.isUtc &&
    value.hour == 0 &&
    value.minute == 0 &&
    value.second == 0 &&
    value.millisecond == 0 &&
    value.microsecond == 0;
