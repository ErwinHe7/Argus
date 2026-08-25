// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/invalidation_bus.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum FutureMirrorPhase {
  idle,
  loading,
  empty,
  ready,
  review,
  generating,
  complete,
  restoredReview,
  reconciliationRequired,
  retryableFailure,
  conflictReview,
  forbidden,
  throttled,
  terminalFailure,
}

class FutureMirrorController extends ChangeNotifier {
  FutureMirrorController({
    required FutureMirrorRepository repository,
    required PendingCommandStore pendingStore,
    required InvalidationBus invalidationBus,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
    required MemberPersonalization personalization,
  }) : _repository = repository,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       ),
       _defaults = FutureMirrorDefaults.forPersonalization(personalization) {
    _invalidationSubscription = invalidationBus
        .eventsFor(scope)
        .listen(_handleInvalidation);
  }

  final FutureMirrorRepository _repository;
  final FinancialCommandJournal _journal;
  final CacheScope scope;
  late final StreamSubscription<InvalidationEvent> _invalidationSubscription;

  FutureMirrorDefaults _defaults;
  FutureMirrorPhase _phase = FutureMirrorPhase.idle;
  FutureMirror? _current;
  FutureMirror? _comparison;
  List<FutureMirror> _history = const [];
  FutureMirrorDraft? _draft;
  JournaledFinancialCommand? _protected;
  Map<FutureMirrorField, String> _fieldErrors = const {};
  String? _intentionId;
  String? _portfolioId;
  int? _ledgerWatermark;
  int? _newerWatermark;
  bool _isStale = false;
  bool _historyIsStale = false;
  bool _authorityFresh = false;
  String? _message;
  Future<void>? _generation;
  bool _disposed = false;

  FutureMirrorDefaults get defaults => _defaults;
  FutureMirrorPhase get phase => _phase;
  FutureMirror? get current => _current;
  FutureMirror? get comparison => _comparison;
  List<FutureMirror> get history => List.unmodifiable(_history);
  FutureMirrorDraft? get draft => _draft;
  Map<FutureMirrorField, String> get fieldErrors =>
      Map.unmodifiable(_fieldErrors);
  bool get isStale => _isStale;
  bool get historyIsStale => _historyIsStale;
  String? get message => _message;
  bool get isGenerating => _generation != null;
  String get historyLabel =>
      'Recent Future Mirror runs seen on this device; not a complete server history.';
  String get operation =>
      'future-mirror.generate:${_intentionId ?? 'unselected'}';

  void updatePersonalization(MemberPersonalization personalization) {
    final next = FutureMirrorDefaults.forPersonalization(personalization);
    if (next.monthlyContributionMinor == _defaults.monthlyContributionMinor &&
        next.lowReturnBps == _defaults.lowReturnBps &&
        next.midReturnBps == _defaults.midReturnBps &&
        next.highReturnBps == _defaults.highReturnBps &&
        next.sourceLabel == _defaults.sourceLabel) {
      return;
    }
    _defaults = next;
    notifyListeners();
  }

  FutureMirrorDraft newDraft() {
    final value = FutureMirrorDraft(
      name: 'Illustrative path',
      monthlyContributionMinor: _defaults.monthlyContributionMinor,
      lowReturnBps: _defaults.lowReturnBps,
      midReturnBps: _defaults.midReturnBps,
      highReturnBps: _defaults.highReturnBps,
    );
    _draft ??= value;
    return value;
  }

  Future<void> openIntention({
    required String intentionId,
    required String portfolioId,
    required int ledgerWatermark,
  }) async {
    if (_intentionId != intentionId || _portfolioId != portfolioId) {
      _intentionId = intentionId;
      _portfolioId = portfolioId;
      _ledgerWatermark = ledgerWatermark;
      _newerWatermark = null;
      _current = null;
      _comparison = null;
      _history = const [];
      _draft = null;
      _protected = null;
      _fieldErrors = const {};
      _isStale = false;
      _phase = FutureMirrorPhase.loading;
      notifyListeners();
    } else {
      _ledgerWatermark = ledgerWatermark;
    }
    final freshAuthority = await _refreshLatest();
    await _refreshHistory();
    final restored = await _journal.restore(operation);
    if (restored == null) return;
    try {
      final recovered = _RecoveredGeneration.fromProtectedMap(
        restored.precondition,
      );
      if (recovered.intentionId != intentionId ||
          recovered.portfolioId != portfolioId ||
          !_validDraft(recovered.draft)) {
        throw const FormatException();
      }
      _protected = restored;
      _draft = recovered.draft;
      if (freshAuthority &&
          _exactAuthority(
            _current,
            recovered.draft,
            recovered.ledgerWatermark,
          )) {
        await _accept(_current!);
        _message = 'The server confirms the saved Future Mirror generation.';
      } else {
        _phase = freshAuthority
            ? FutureMirrorPhase.restoredReview
            : FutureMirrorPhase.reconciliationRequired;
        _message = freshAuthority
            ? 'The latest result did not prove this saved generation. Review the exact assumptions before a same-key recovery.'
            : 'Projection authority is unavailable. Nothing will retry automatically.';
      }
    } on Object {
      await _journal.clear(operation);
      _protected = null;
      _draft = null;
      _phase = FutureMirrorPhase.terminalFailure;
      _message =
          'The protected Future Mirror review is unsupported. Start again.';
    }
    notifyListeners();
  }

  void prepare(FutureMirrorDraft draft) {
    if (_generation != null) return;
    if (_protected != null) {
      _message = 'Resolve the saved Future Mirror before starting another.';
      notifyListeners();
      return;
    }
    final errors = _validateDraft(draft);
    if (errors.isNotEmpty) {
      _fieldErrors = errors;
      _message = 'Review the highlighted illustrative assumptions.';
      notifyListeners();
      return;
    }
    _draft = draft;
    _fieldErrors = const {};
    _phase = FutureMirrorPhase.review;
    _message =
        'Review editable Demo assumptions. Nothing generates automatically.';
    notifyListeners();
  }

  void reviewRestoredGeneration() {
    if (_phase != FutureMirrorPhase.restoredReview &&
        _phase != FutureMirrorPhase.retryableFailure &&
        _phase != FutureMirrorPhase.throttled) {
      return;
    }
    _phase = FutureMirrorPhase.review;
    _message = 'Review the unchanged assumptions before the same-key recovery.';
    notifyListeners();
  }

  Future<void> retryReconciliation() async {
    if (_phase != FutureMirrorPhase.reconciliationRequired ||
        _protected == null ||
        _draft == null) {
      return;
    }
    final recovered = _RecoveredGeneration.fromProtectedMap(
      _protected!.precondition,
    );
    final fresh = await _refreshLatest();
    if (fresh &&
        _exactAuthority(_current, recovered.draft, recovered.ledgerWatermark)) {
      await _accept(_current!);
      _message = 'The server confirms the saved Future Mirror generation.';
    } else if (fresh) {
      _phase = FutureMirrorPhase.restoredReview;
      _message = 'Authority is current. Review the unchanged assumptions before recovery.';
    } else {
      _phase = FutureMirrorPhase.reconciliationRequired;
      _message =
          'Projection authority is still unavailable. Nothing was submitted.';
    }
    notifyListeners();
  }

  Future<void> discardPendingGeneration() async {
    if (_protected == null ||
        !_authorityFresh ||
        (_phase != FutureMirrorPhase.restoredReview &&
            _phase != FutureMirrorPhase.retryableFailure &&
            _phase != FutureMirrorPhase.throttled)) {
      return;
    }
    await _journal.clear(operation);
    _protected = null;
    _draft = null;
    _fieldErrors = const {};
    _phase = _current == null
        ? FutureMirrorPhase.empty
        : FutureMirrorPhase.complete;
    _message = 'Saved projection recovery discarded after fresh authority and explicit review.';
    notifyListeners();
  }

  Future<void> confirm() {
    final active = _generation;
    if (active != null) return active;
    if (_phase != FutureMirrorPhase.review || _draft == null) {
      return Future.value();
    }
    late final Future<void> operation;
    operation = _confirm().whenComplete(() {
      if (identical(_generation, operation)) {
        _generation = null;
        if (!_disposed) notifyListeners();
      }
    });
    _generation = operation;
    notifyListeners();
    return operation;
  }

  Future<void> _confirm() async {
    final draft = _draft!;
    final intentionId = _intentionId;
    final portfolioId = _portfolioId;
    final watermark = _protected == null
        ? _ledgerWatermark
        : _RecoveredGeneration.fromProtectedMap(_protected!.precondition)
              .ledgerWatermark;
    if (intentionId == null ||
        portfolioId == null ||
        watermark == null ||
        watermark < 1) {
      _phase = FutureMirrorPhase.reconciliationRequired;
      _message =
          'Refresh authoritative Demo activity before generating a projection.';
      notifyListeners();
      return;
    }
    final payload = draft.toCanonicalMap();
    final snapshot = _RecoveredGeneration(
      intentionId: intentionId,
      portfolioId: portfolioId,
      ledgerWatermark: watermark,
      draft: draft,
    ).toProtectedMap();
    final existing = _protected;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _journal.clear(operation);
      _protected = null;
      _phase = FutureMirrorPhase.conflictReview;
      _message = 'The assumptions changed. Start a new reviewed generation.';
      return;
    }
    _protected = await _journal.protect(
      operation: operation,
      payload: payload,
      precondition: existing?.precondition ?? snapshot,
      reuse: existing,
    );
    _phase = FutureMirrorPhase.generating;
    _fieldErrors = const {};
    _message = null;
    notifyListeners();
    try {
      final value = await _repository.generate(
        FutureMirrorGenerate(
          intentionId: intentionId,
          draft: draft,
          idempotencyKey: _protected!.key,
        ),
      );
      _requireResult(value);
      await _accept(value);
      _message = 'Future Mirror completed from authoritative Demo activity.';
    } on AmbiguousFutureMirrorGeneration {
      await _reconcileAmbiguous(draft, watermark);
    } on FutureMirrorValidationFailure catch (failure) {
      await _journal.clear(operation);
      _protected = null;
      _fieldErrors = failure.fieldErrors;
      _phase = FutureMirrorPhase.review;
      _message = 'The server rejected the highlighted assumptions. Review and generate again.';
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
      if (_phase == FutureMirrorPhase.forbidden ||
          _phase == FutureMirrorPhase.terminalFailure ||
          _phase == FutureMirrorPhase.conflictReview) {
        await _journal.clear(operation);
        _protected = null;
      }
    }
    notifyListeners();
  }

  Future<void> _reconcileAmbiguous(
    FutureMirrorDraft draft,
    int watermark,
  ) async {
    final fresh = await _refreshLatest();
    if (fresh && _exactAuthority(_current, draft, watermark)) {
      await _accept(_current!);
      _message = 'The server confirms this Future Mirror completed once.';
      return;
    }
    _phase = fresh
        ? FutureMirrorPhase.retryableFailure
        : FutureMirrorPhase.reconciliationRequired;
    _message = fresh
        ? 'The latest result did not prove the saved generation. Review unchanged assumptions before a same-key recovery.'
        : 'The response was lost and authority is unavailable. Nothing will retry automatically.';
  }

  Future<void> refreshLatest() async {
    await _refreshLatest();
    await _refreshHistory();
    notifyListeners();
  }

  Future<void> compareWith(String runId) async {
    final intentionId = _intentionId;
    if (intentionId == null) return;
    try {
      final result = await _repository.get(intentionId, runId);
      _requireResult(result.value);
      _comparison = result.value;
      _historyIsStale = result.isStale;
      _message = result.isStale
          ? 'Comparison is cached until projection history reconnects.'
          : null;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
  }

  Future<bool> _refreshLatest() async {
    final intentionId = _intentionId;
    if (intentionId == null) return false;
    try {
      final result = await _repository.latest(intentionId);
      if (result.value case final value?) _requireResult(value);
      _current = result.value;
      _isStale =
          result.isStale ||
          (_newerWatermark != null &&
              (_current?.ledgerWatermark ?? 0) < _newerWatermark!);
      _phase = _current == null
          ? FutureMirrorPhase.empty
          : FutureMirrorPhase.complete;
      _message = result.isStale
          ? 'Showing a cached historical scenario until the Demo service reconnects.'
          : null;
      _authorityFresh = !result.isStale;
      notifyListeners();
      return !result.isStale;
    } on OfflineException {
      _authorityFresh = false;
      _phase = FutureMirrorPhase.retryableFailure;
      _message =
          'Projection authority is offline; existing source data is preserved.';
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.empty) {
        _current = null;
        _phase = FutureMirrorPhase.empty;
        _authorityFresh = true;
        return true;
      }
      _authorityFresh = false;
      _mapFailure(failure, preserveValue: true);
    } on Object catch (error) {
      _authorityFresh = false;
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
    return false;
  }

  Future<void> _refreshHistory() async {
    final intentionId = _intentionId;
    if (intentionId == null) return;
    try {
      final results = await _repository.recent(intentionId);
      for (final result in results) {
        _requireResult(result.value);
      }
      _history = results.map((item) => item.value).toList(growable: false);
      _historyIsStale = results.any((item) => item.isStale);
    } on Object {
      _historyIsStale = true;
    }
  }

  Future<void> _accept(FutureMirror value) async {
    _requireResult(value);
    await _journal.clear(operation);
    _protected = null;
    _draft = null;
    _fieldErrors = const {};
    _current = value;
    _isStale =
        _newerWatermark != null && value.ledgerWatermark < _newerWatermark!;
    _phase = FutureMirrorPhase.complete;
    await _repository.remember(value);
    await _refreshHistory();
  }

  void _requireResult(FutureMirror value) {
    if (value.intentionId != _intentionId) {
      throw const LoadFailure(LoadPhase.forbidden);
    }
  }

  bool _exactAuthority(
    FutureMirror? value,
    FutureMirrorDraft draft,
    int ledgerWatermark,
  ) =>
      value != null &&
      value.intentionId == _intentionId &&
      value.ledgerWatermark == ledgerWatermark &&
      value.assumptions.exactlyMatches(draft);

  void _handleInvalidation(InvalidationEvent event) {
    if (_disposed || event.resource != InvalidationResource.ledger) return;
    final watermark = event.ledgerWatermark;
    if (watermark == null || watermark <= (_current?.ledgerWatermark ?? 0)) {
      return;
    }
    _newerWatermark = watermark;
    _ledgerWatermark = watermark;
    _isStale = _current != null;
    _message = _current == null
        ? 'New Demo activity is available for a first projection.'
        : 'New Demo activity makes this historical scenario stale. Regenerate after reviewing assumptions.';
    notifyListeners();
  }

  void _mapFailure(Object error, {bool preserveValue = false}) {
    final failure = switch (error) {
      OfflineException() => const LoadFailure(LoadPhase.retryableFailure),
      LoadFailure() => error,
      _ => const LoadFailure(LoadPhase.terminalFailure),
    };
    _phase = switch (failure.phase) {
      LoadPhase.forbidden => FutureMirrorPhase.forbidden,
      LoadPhase.conflict => FutureMirrorPhase.conflictReview,
      LoadPhase.throttled => FutureMirrorPhase.throttled,
      LoadPhase.retryableFailure => FutureMirrorPhase.retryableFailure,
      _ => FutureMirrorPhase.terminalFailure,
    };
    if (!preserveValue) _current = null;
    _message =
        failure.message ??
        switch (_phase) {
          FutureMirrorPhase.retryableFailure =>
            'Future Mirror is unavailable; existing source data is preserved.',
          FutureMirrorPhase.throttled => 'Projection generation is paused briefly. Your review is preserved.',
          FutureMirrorPhase.forbidden =>
            'This projection is not available for this Intention.',
          FutureMirrorPhase.conflictReview => 'Authoritative Demo activity changed. Refresh and review assumptions.',
          _ => 'This Future Mirror result could not be loaded.',
        };
  }

  Map<FutureMirrorField, String> _validateDraft(FutureMirrorDraft draft) {
    final errors = <FutureMirrorField, String>{};
    if (draft.name.trim().isEmpty || draft.name.trim().length > 80) {
      errors[FutureMirrorField.name] = 'Use 1–80 characters.';
    }
    if (draft.monthlyContributionMinor < 0 ||
        draft.monthlyContributionMinor > 1000000000) {
      errors[FutureMirrorField.monthlyContribution] =
          'Use a Demo amount from 0 to 10,000,000.00 USD.';
    }
    final returns = {
      FutureMirrorField.lowReturn: draft.lowReturnBps,
      FutureMirrorField.midReturn: draft.midReturnBps,
      FutureMirrorField.highReturn: draft.highReturnBps,
    };
    for (final entry in returns.entries) {
      if (entry.value < -5000 || entry.value > 5000) {
        errors[entry.key] = 'Use a value from -50% to 50%.';
      }
    }
    if (draft.lowReturnBps > draft.midReturnBps ||
        draft.midReturnBps > draft.highReturnBps) {
      errors[FutureMirrorField.lowReturn] ??= 'Keep low ≤ base ≤ high.';
      errors[FutureMirrorField.midReturn] ??= 'Keep low ≤ base ≤ high.';
      errors[FutureMirrorField.highReturn] ??= 'Keep low ≤ base ≤ high.';
    }
    return errors;
  }

  bool _validDraft(FutureMirrorDraft draft) => _validateDraft(draft).isEmpty;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_invalidationSubscription.cancel());
    super.dispose();
  }
}

class _RecoveredGeneration {
  const _RecoveredGeneration({
    required this.intentionId,
    required this.portfolioId,
    required this.ledgerWatermark,
    required this.draft,
  });

  factory _RecoveredGeneration.fromProtectedMap(Map<String, Object?> value) {
    if (value.length != 4 ||
        value['intention_id'] is! String ||
        value['portfolio_id'] is! String ||
        value['ledger_watermark'] is! int ||
        value['assumptions'] is! Map<String, Object?>) {
      throw const FormatException('Unsupported projection recovery.');
    }
    return _RecoveredGeneration(
      intentionId: value['intention_id']! as String,
      portfolioId: value['portfolio_id']! as String,
      ledgerWatermark: value['ledger_watermark']! as int,
      draft: FutureMirrorDraft.fromProtectedMap(
        value['assumptions']! as Map<String, Object?>,
      ),
    );
  }

  final String intentionId;
  final String portfolioId;
  final int ledgerWatermark;
  final FutureMirrorDraft draft;

  Map<String, Object?> toProtectedMap() => {
    'intention_id': intentionId,
    'portfolio_id': portfolioId,
    'ledger_watermark': ledgerWatermark,
    'assumptions': draft.toCanonicalMap(),
  };
}
