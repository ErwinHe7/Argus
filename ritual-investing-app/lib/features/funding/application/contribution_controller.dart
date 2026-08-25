// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/invalidation_bus.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../portfolio/application/controller.dart';
import '../../portfolio/domain/model.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum ContributionPhase {
  idle,
  review,
  confirming,
  restoredReview,
  reconciliationRequired,
  retryableFailure,
  conflictReview,
  forbidden,
  throttled,
  terminalFailure,
  receipt,
  receiptRefreshPending,
}

class ContributionController extends ChangeNotifier {
  ContributionController({
    required FundingRepository repository,
    required this.portfolioController,
    required PendingCommandStore pendingStore,
    required InvalidationBus invalidationBus,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
    required MemberContributionRhythm rhythm,
  }) : _repository = repository,
       _pendingStore = pendingStore,
       _invalidationBus = invalidationBus,
       _createKey = createKey,
       _now = now,
       defaults = ContributionDefaults.forRhythm(rhythm);

  final FundingRepository _repository;
  final PortfolioController portfolioController;
  final PendingCommandStore _pendingStore;
  final InvalidationBus _invalidationBus;
  final CacheScope scope;
  final String Function() _createKey;
  final DateTime Function() _now;
  final ContributionDefaults defaults;
  ContributionPhase _phase = ContributionPhase.idle;
  ContributionDraft? _draft;
  ContributionReceipt? _receipt;
  RestoredPendingCommand? _restored;
  String? _commandKey;
  DateTime? _commandCreatedAt;
  String? _commandPrecondition;
  bool _authorityReconciled = true;
  String? _portfolioId;
  String? _message;
  Future<void>? _confirmationOperation;

  ContributionPhase get phase => _phase;
  ContributionDraft? get draft => _draft;
  ContributionReceipt? get receipt => _receipt;
  String? get message => _message;
  bool get isConfirming => _confirmationOperation != null;
  String get operation =>
      _operationFor(_portfolioId ?? _draft?.portfolioId ?? 'unselected');

  Future<void> openPortfolio(String portfolioId) async {
    if (_portfolioId == portfolioId) return;
    _portfolioId = portfolioId;
    _phase = ContributionPhase.idle;
    _draft = null;
    _receipt = null;
    _restored = null;
    _commandKey = null;
    _commandCreatedAt = null;
    _commandPrecondition = null;
    _authorityReconciled = true;
    _message = null;
    notifyListeners();
    await restorePending(portfolioId);
  }

  Future<bool> prepare({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    DateTime? effectiveAt,
  }) async {
    if (_phase == ContributionPhase.receiptRefreshPending) {
      _message = 'Refresh the committed Demo receipt before preparing another contribution.';
      notifyListeners();
      return false;
    }
    if (_restored != null && !_authorityReconciled) {
      _message = 'Refresh the authoritative portfolio before reviewing this saved command.';
      notifyListeners();
      return false;
    }
    final validation = _validate(
      portfolioId: portfolioId,
      sourceId: sourceId,
      minorUnits: minorUnits,
    );
    if (validation != null) {
      _message = validation;
      notifyListeners();
      return false;
    }
    final candidate = ContributionDraft(
      portfolioId: portfolioId,
      sourceId: sourceId,
      minorUnits: minorUnits,
      currency: PortfolioCurrency.usd,
      effectiveAt: effectiveAt?.toUtc(),
    );
    final restored = _restored;
    if (restored != null &&
        restored.command.canonicalPayloadHash != _payloadHash(candidate)) {
      await _pendingStore.clear(scope, restored.command.operation);
      _restored = null;
      _commandKey = _createKey();
      _commandCreatedAt = null;
      _commandPrecondition = null;
      _message = 'Your Demo contribution changed. Review the new details before confirming.';
    } else if (restored != null) {
      _commandKey = restored.command.key;
      _commandCreatedAt = restored.command.createdAt;
      _commandPrecondition = restored.command.precondition;
      _message = 'Review the restored Demo contribution. It will never retry automatically.';
    } else {
      _commandKey = _createKey();
      _commandCreatedAt = null;
      _commandPrecondition = null;
      _message = null;
    }
    _portfolioId = portfolioId;
    _draft = candidate;
    _receipt = null;
    _phase = ContributionPhase.review;
    notifyListeners();
    return true;
  }

  Future<void> restorePending(String portfolioId) async {
    _portfolioId = portfolioId;
    final restored = await _pendingStore.restore(
      scope,
      _operationFor(portfolioId),
    );
    if (restored == null) return;
    _restored = restored;
    _commandKey = restored.command.key;
    _commandCreatedAt = restored.command.createdAt;
    _commandPrecondition = restored.command.precondition;
    _authorityReconciled = await portfolioController.refreshPortfolio(
      portfolioId,
    );
    _phase = _authorityReconciled
        ? ContributionPhase.restoredReview
        : ContributionPhase.reconciliationRequired;
    _message = _authorityReconciled
        ? 'A prior confirmation may have reached the Demo ledger. Review the same source and amount to resolve it safely.'
        : 'Refresh the authoritative portfolio before reviewing this saved command.';
    notifyListeners();
  }

  Future<void> retryPendingReconciliation() async {
    final portfolioId = _portfolioId ?? _draft?.portfolioId;
    if (portfolioId == null ||
        _phase != ContributionPhase.reconciliationRequired) {
      return;
    }
    _authorityReconciled = await portfolioController.refreshPortfolio(
      portfolioId,
    );
    if (_authorityReconciled) {
      _phase = _draft == null
          ? ContributionPhase.restoredReview
          : ContributionPhase.conflictReview;
      _message = _draft == null
          ? 'Authority is current. Re-enter and review the unchanged saved contribution.'
          : 'Authority is current. Review the unchanged command before retrying.';
    } else {
      _message = 'The authoritative portfolio is still unavailable. Nothing was submitted.';
    }
    notifyListeners();
  }

  void reviewSameContribution() {
    if (_draft == null) return;
    if (_phase == ContributionPhase.retryableFailure ||
        _phase == ContributionPhase.conflictReview ||
        _phase == ContributionPhase.throttled) {
      _phase = ContributionPhase.review;
      _message = 'Review the unchanged Demo contribution before retrying the same command.';
      notifyListeners();
    }
  }

  Future<void> confirm() {
    final active = _confirmationOperation;
    if (active != null) return active;
    if (_phase != ContributionPhase.review || _draft == null) {
      return Future.value();
    }
    late final Future<void> operation;
    operation = _confirm().whenComplete(() {
      if (identical(_confirmationOperation, operation)) {
        _confirmationOperation = null;
        notifyListeners();
      }
    });
    _confirmationOperation = operation;
    notifyListeners();
    return operation;
  }

  Future<void> _confirm() async {
    final draft = _draft!;
    final key = _commandKey ?? _createKey();
    _commandKey = key;
    final authority = portfolioController.detailState.value?.portfolio;
    final precondition =
        _commandPrecondition ??
        (authority == null
            ? 'portfolio:${draft.portfolioId}:unobserved'
            : 'portfolio:${draft.portfolioId}:v${authority.version}:w${authority.ledgerWatermark}');
    final createdAt = _commandCreatedAt ?? _now().toUtc();
    _commandPrecondition = precondition;
    _commandCreatedAt = createdAt;
    await _pendingStore.save(
      PendingCommand(
        scope: scope,
        operation: _operationFor(draft.portfolioId),
        key: key,
        precondition: precondition,
        canonicalPayloadHash: _payloadHash(draft),
        createdAt: createdAt,
      ),
    );
    _phase = ContributionPhase.confirming;
    _message = null;
    notifyListeners();
    try {
      final value = await _repository.contribute(
        ContributionCommand(
          portfolioId: draft.portfolioId,
          sourceId: draft.sourceId,
          minorUnits: draft.minorUnits,
          currency: draft.currency,
          effectiveAt: draft.effectiveAt,
          idempotencyKey: key,
        ),
      );
      _receipt = value;
      await _pendingStore.clear(scope, _operationFor(draft.portfolioId));
      _restored = null;
      _commandCreatedAt = null;
      _commandPrecondition = null;
      await _refreshCommittedReceipt(
        draft.portfolioId,
        publishInvalidation: true,
      );
    } on AmbiguousContributionFailure {
      _phase = ContributionPhase.retryableFailure;
      _message = 'The response was lost. Review this unchanged contribution before a same-key retry.';
    } on OfflineException {
      _phase = ContributionPhase.retryableFailure;
      _message = 'You are offline. No receipt is shown; review before retrying this saved command.';
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.conflict) {
        final reconciled = await portfolioController.refreshPortfolio(
          draft.portfolioId,
        );
        _authorityReconciled = reconciled;
        _phase = reconciled
            ? ContributionPhase.conflictReview
            : ContributionPhase.reconciliationRequired;
        _message = reconciled
            ? _failureMessage(ContributionPhase.conflictReview)
            : 'Refresh the authoritative portfolio before reviewing this saved command.';
        notifyListeners();
        return;
      }
      _phase = switch (failure.phase) {
        LoadPhase.forbidden => ContributionPhase.forbidden,
        LoadPhase.throttled => ContributionPhase.throttled,
        LoadPhase.retryableFailure => ContributionPhase.retryableFailure,
        _ => ContributionPhase.terminalFailure,
      };
      if (_phase == ContributionPhase.forbidden ||
          _phase == ContributionPhase.terminalFailure) {
        await _pendingStore.clear(scope, _operationFor(draft.portfolioId));
        _restored = null;
        _commandKey = null;
        _commandCreatedAt = null;
        _commandPrecondition = null;
      }
      _message = _failureMessage(_phase);
    }
    notifyListeners();
  }

  Future<void> retryPortfolioRefresh() async {
    final portfolioId = _draft?.portfolioId ?? _portfolioId;
    if (_receipt == null || portfolioId == null) return;
    await _refreshCommittedReceipt(portfolioId, publishInvalidation: true);
    notifyListeners();
  }

  Future<void> _refreshCommittedReceipt(
    String portfolioId, {
    required bool publishInvalidation,
  }) async {
    final refreshed = await portfolioController.refreshPortfolio(portfolioId);
    final watermark =
        refreshed && portfolioController.detailState.phase == LoadPhase.ready
        ? portfolioController.detailState.value?.portfolio.ledgerWatermark
        : null;
    if (publishInvalidation) {
      _invalidationBus.publish(
        InvalidationEvent(
          scope: scope,
          resource: 'ledger',
          ledgerWatermark: watermark,
        ),
      );
    }
    if (watermark == null) {
      _phase = ContributionPhase.receiptRefreshPending;
      _message = 'The Demo receipt committed. Refresh the portfolio to reconcile its watermark.';
      return;
    }
    _phase = ContributionPhase.receipt;
    _message = 'Demo ledger reconciled at watermark $watermark.';
  }
}

String _operationFor(String portfolioId) =>
    'create_demo_contribution:$portfolioId';

String _payloadHash(ContributionDraft draft) {
  final value = <String, Object?>{
    'amount_minor': draft.minorUnits,
    'currency': 'USD',
    'effective_at': draft.effectiveAt?.toUtc().toIso8601String(),
    'portfolio_id': draft.portfolioId,
    'source_id': draft.sourceId,
  };
  return sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

String? _validate({
  required String portfolioId,
  required String sourceId,
  required int minorUnits,
}) {
  if (portfolioId.trim().isEmpty) return 'Choose a Demo portfolio.';
  if (sourceId.trim().isEmpty) return 'Choose a fictional funding source.';
  if (minorUnits < 1 || minorUnits > 1000000000) {
    return 'Enter a Demo amount from \$0.01 to \$10,000,000.00.';
  }
  return null;
}

String _failureMessage(ContributionPhase phase) => switch (phase) {
  ContributionPhase.forbidden =>
    'This account is not allowed to confirm Demo contributions.',
  ContributionPhase.conflictReview =>
    'The server state changed. Refresh, review, and explicitly confirm again.',
  ContributionPhase.throttled =>
    'Too many attempts. Wait, then review this unchanged command again.',
  ContributionPhase.retryableFailure =>
    'The Demo service is unavailable. Review before retrying.',
  _ => 'This contribution could not be accepted. Edit or try again later.',
};
