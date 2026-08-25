// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/invalidation_bus.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../portfolio/application/controller.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum RebalancePhase {
  idle,
  previewing,
  review,
  confirming,
  restoredReview,
  reconciliationRequired,
  retryableFailure,
  previewInvalidated,
  alreadyBalanced,
  forbidden,
  throttled,
  terminalFailure,
  receipt,
  receiptRefreshPending,
}

class RebalanceController extends ChangeNotifier {
  RebalanceController({
    required RebalanceRepository repository,
    required this.portfolioController,
    required PendingCommandStore pendingStore,
    required InvalidationBus invalidationBus,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
  }) : _repository = repository,
       _invalidationBus = invalidationBus,
       _now = now,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       );

  final RebalanceRepository _repository;
  final PortfolioController portfolioController;
  final InvalidationBus _invalidationBus;
  final CacheScope scope;
  final DateTime Function() _now;
  final FinancialCommandJournal _journal;
  String? _portfolioId;
  RebalancePhase _phase = RebalancePhase.idle;
  RebalancePreview? _activePreview;
  RebalanceReceipt? _receipt;
  JournaledFinancialCommand? _protected;
  String? _message;
  Future<void>? _operation;

  RebalancePhase get phase => _phase;
  RebalancePreview? get activePreview => _activePreview;
  RebalanceReceipt? get receipt => _receipt;
  String? get message => _message;
  bool get isConfirming => _operation != null;
  String get operation => 'rebalance.commit:${_portfolioId ?? 'unselected'}';

  Future<void> openPortfolio(String portfolioId) async {
    if (_portfolioId != portfolioId) {
      _portfolioId = portfolioId;
      _activePreview = null;
      _receipt = null;
      _protected = null;
      _phase = RebalancePhase.idle;
      _message = null;
      notifyListeners();
    }
    final restored = await _journal.restore(operation);
    if (restored == null) return;
    try {
      final preview = RebalancePreview.fromProtectedMap(restored.precondition);
      if (preview.portfolioId != portfolioId ||
          !preview.expiresAt.isAfter(_now().toUtc())) {
        await _journal.clear(operation);
        _phase = RebalancePhase.previewInvalidated;
        _message = 'The saved rebalance preview expired. Create a fresh allocation review.';
        notifyListeners();
        return;
      }
      _protected = restored;
      _activePreview = preview;
      final reconciled = await portfolioController.refreshPortfolio(portfolioId);
      _phase = reconciled
          ? RebalancePhase.restoredReview
          : RebalancePhase.reconciliationRequired;
      _message = reconciled
          ? 'A prior rebalance confirmation may have reached the Demo ledger. Review every saved trade before a same-key retry.'
          : 'Refresh authoritative portfolio reads before reviewing the saved rebalance.';
    } on Object {
      await _journal.clear(operation);
      _protected = null;
      _activePreview = null;
      _phase = RebalancePhase.previewInvalidated;
      _message = 'The saved rebalance review failed integrity checks. Create a fresh preview.';
    }
    notifyListeners();
  }

  Future<bool> preview({
    required String portfolioId,
    required List<RebalanceAllocation> allocations,
  }) async {
    if (_protected != null) {
      _message = 'Resolve or explicitly discard the saved rebalance confirmation before creating another preview.';
      notifyListeners();
      return false;
    }
    if (!validRebalanceAllocations(allocations)) {
      _message = 'Use unique Demo assets, 0–100% each, totaling exactly 100%.';
      notifyListeners();
      return false;
    }
    _portfolioId = portfolioId;
    _receipt = null;
    _phase = RebalancePhase.previewing;
    _message = null;
    notifyListeners();
    try {
      final value = await _repository.preview(portfolioId, allocations);
      if (value.status != RebalancePreviewStatus.active ||
          !value.expiresAt.isAfter(_now().toUtc()) ||
          !validRebalanceAllocations(value.targetAllocation) ||
          value.trades.isEmpty) {
        throw const RebalanceCommitFailure.stalePreview();
      }
      _activePreview = value;
      _phase = RebalancePhase.review;
      _message = 'Review every frozen Demo trade. Nothing submits until explicit confirmation.';
      notifyListeners();
      return true;
    } on Object catch (error) {
      _activePreview = null;
      _mapFailure(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> reviewRestoredCommit() async {
    if (_phase != RebalancePhase.restoredReview &&
        _phase != RebalancePhase.retryableFailure &&
        _phase != RebalancePhase.throttled) {
      return;
    }
    if (_activePreview == null ||
        !_activePreview!.expiresAt.isAfter(_now().toUtc())) {
      await _invalidate('The saved rebalance preview expired. Create a fresh preview.');
      return;
    }
    _phase = RebalancePhase.review;
    _message = 'Review the unchanged saved allocations and trades before a same-key retry.';
    notifyListeners();
  }

  Future<void> discardPendingCommit() async {
    if (_protected == null ||
        (_phase != RebalancePhase.restoredReview &&
            _phase != RebalancePhase.retryableFailure)) {
      return;
    }
    await _journal.clear(operation);
    _protected = null;
    _activePreview = null;
    _phase = RebalancePhase.idle;
    _message = 'Saved rebalance confirmation explicitly discarded. A fresh preview will use a new key.';
    notifyListeners();
  }

  Future<void> confirm() {
    final current = _operation;
    if (current != null) return current;
    if (_phase != RebalancePhase.review || _activePreview == null) return Future.value();
    late final Future<void> request;
    request = _confirm().whenComplete(() {
      if (identical(_operation, request)) {
        _operation = null;
        notifyListeners();
      }
    });
    _operation = request;
    notifyListeners();
    return request;
  }

  Future<void> _confirm() async {
    final preview = _activePreview!;
    if (!preview.expiresAt.isAfter(_now().toUtc())) {
      await _invalidate('The Demo preview expired. Create a fresh allocation review.');
      return;
    }
    final payload = <String, Object?>{
      'portfolio_id': preview.portfolioId,
      'preview_id': preview.id,
      'portfolio_version': preview.portfolioVersion,
    };
    final existing = _protected;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _invalidate('The rebalance command changed. Create a fresh preview.');
      return;
    }
    _protected = await _journal.protect(
      operation: operation,
      payload: payload,
      precondition: preview.toProtectedMap(),
      reuse: existing,
    );
    _phase = RebalancePhase.confirming;
    _message = null;
    notifyListeners();
    try {
      _receipt = await _repository.commit(
        RebalanceCommit(
          portfolioId: preview.portfolioId,
          previewId: preview.id,
          portfolioVersion: preview.portfolioVersion,
          idempotencyKey: _protected!.key,
        ),
      );
      await _journal.clear(operation);
      _protected = null;
      await _refreshAccepted(preview.portfolioId);
    } on RebalanceCommitFailure catch (failure) {
      if (failure.reason == RebalanceCommitFailureReason.stalePreview) {
        await portfolioController.refreshPortfolio(preview.portfolioId);
        await _invalidate('The portfolio or preview changed. Create and review a fresh rebalance.');
      } else {
        await _clearTerminal();
        _phase = RebalancePhase.terminalFailure;
        _message = 'The Demo rebalance was rejected.';
      }
    } on AmbiguousRebalanceFailure {
      await _handleAmbiguous(preview.portfolioId);
    } on OfflineException {
      await _handleAmbiguous(preview.portfolioId);
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.conflict) {
        await portfolioController.refreshPortfolio(preview.portfolioId);
        await _invalidate('The Demo rebalance preview is stale. Create a fresh review.');
      } else {
        _phase = _phaseFor(failure.phase);
        _message = failure.message;
        if (_phase == RebalancePhase.forbidden ||
            _phase == RebalancePhase.terminalFailure) {
          await _clearTerminal();
        }
      }
    }
    notifyListeners();
  }

  Future<void> retryReconciliation() async {
    final portfolioId = _portfolioId;
    if (portfolioId == null) return;
    final reconciled = await portfolioController.refreshPortfolio(portfolioId);
    if (reconciled) {
      _phase = RebalancePhase.restoredReview;
      _message = 'Authority is current. Review every saved trade before a same-key retry.';
    }
    notifyListeners();
  }

  Future<void> retryReceiptRefresh() async {
    final portfolioId = _portfolioId;
    if (_receipt == null || portfolioId == null) return;
    await _refreshAccepted(portfolioId);
    notifyListeners();
  }

  Future<void> _refreshAccepted(String portfolioId) async {
    final ready = await portfolioController.refreshPortfolio(portfolioId);
    final watermark = ready
        ? portfolioController.detailState.value?.portfolio.ledgerWatermark
        : null;
    _invalidationBus.publish(
      InvalidationEvent(scope: scope, resource: 'ledger', ledgerWatermark: watermark),
    );
    if (watermark == null) {
      _phase = RebalancePhase.receiptRefreshPending;
      _message = 'The Demo receipt committed. Authoritative portfolio reads are still refreshing.';
    } else {
      _phase = RebalancePhase.receipt;
      _message = 'Demo ledger reconciled at watermark $watermark.';
    }
  }

  Future<void> _handleAmbiguous(String portfolioId) async {
    final reconciled = await portfolioController.refreshPortfolio(portfolioId);
    _phase = reconciled
        ? RebalancePhase.retryableFailure
        : RebalancePhase.reconciliationRequired;
    _message = reconciled
        ? 'The response was lost. Review all unchanged saved trades before a same-key retry.'
        : 'Authority is unavailable. Nothing will retry automatically.';
  }

  Future<void> _invalidate(String message) async {
    await _journal.clear(operation);
    _protected = null;
    _activePreview = null;
    _phase = RebalancePhase.previewInvalidated;
    _message = message;
    notifyListeners();
  }

  Future<void> _clearTerminal() async {
    await _journal.clear(operation);
    _protected = null;
    _activePreview = null;
  }

  void _mapFailure(Object error) {
    if (error is RebalanceCommitFailure &&
        error.reason == RebalanceCommitFailureReason.stalePreview) {
      _phase = RebalancePhase.previewInvalidated;
      _message = 'Create a fresh Demo rebalance preview.';
    } else if (error is RebalanceAlreadyBalanced) {
      _phase = RebalancePhase.alreadyBalanced;
      _message = 'This Demo portfolio already matches the reviewed allocation. No command is needed.';
    } else if (error is OfflineException) {
      _phase = RebalancePhase.retryableFailure;
      _message = 'Rebalance preview is offline. Nothing was submitted.';
    } else if (error is LoadFailure) {
      _phase = _phaseFor(error.phase);
      _message = error.message;
    } else {
      _phase = RebalancePhase.terminalFailure;
      _message = 'The rebalance response is not supported by this app version.';
    }
  }
}

RebalancePhase _phaseFor(LoadPhase phase) => switch (phase) {
  LoadPhase.forbidden => RebalancePhase.forbidden,
  LoadPhase.throttled => RebalancePhase.throttled,
  LoadPhase.retryableFailure => RebalancePhase.retryableFailure,
  LoadPhase.conflict => RebalancePhase.previewInvalidated,
  _ => RebalancePhase.terminalFailure,
};
