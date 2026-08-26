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

enum OrderCommandPhase {
  idle,
  loading,
  listReady,
  empty,
  previewing,
  review,
  confirming,
  restoredReview,
  reconciliationRequired,
  retryableFailure,
  previewInvalidated,
  forbidden,
  throttled,
  terminalFailure,
  receipt,
  receiptRefreshPending,
}

class OrderController extends ChangeNotifier {
  OrderController({
    required OrderRepository repository,
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

  final OrderRepository _repository;
  final PortfolioController portfolioController;
  final InvalidationBus _invalidationBus;
  final CacheScope scope;
  final DateTime Function() _now;
  final FinancialCommandJournal _journal;
  String? _portfolioId;
  OrderCommandPhase _phase = OrderCommandPhase.idle;
  List<OrderView> _orders = const [];
  OrderView? _selectedOrder;
  OrderPreview? _activePreview;
  OrderReceipt? _receipt;
  JournaledFinancialCommand? _protected;
  String? _message;
  Future<void>? _commitOperation;

  OrderCommandPhase get phase => _phase;
  List<OrderView> get orders => _orders;
  OrderView? get selectedOrder => _selectedOrder;
  OrderPreview? get activePreview => _activePreview;
  OrderReceipt? get receipt => _receipt;
  String? get message => _message;
  bool get isConfirming => _commitOperation != null;
  String get operation => 'order.commit:${_portfolioId ?? 'unselected'}';

  Future<void> openPortfolio(String portfolioId) async {
    if (_portfolioId != portfolioId) {
      _portfolioId = portfolioId;
      _phase = OrderCommandPhase.loading;
      _orders = const [];
      _selectedOrder = null;
      _activePreview = null;
      _receipt = null;
      _protected = null;
      _message = null;
      notifyListeners();
    }
    await _refreshOrders();
    final restored = await _journal.restore(operation);
    if (restored == null) return;
    try {
      final preview = OrderPreview.fromProtectedMap(restored.precondition);
      if (preview.portfolioId != portfolioId ||
          preview.expiresAt.isBefore(_now().toUtc()) ||
          preview.expiresAt.isAtSameMomentAs(_now().toUtc())) {
        await _journal.clear(operation);
        _phase = OrderCommandPhase.previewInvalidated;
        _message = 'The saved Demo preview expired. Create and review a fresh preview.';
        notifyListeners();
        return;
      }
      _protected = restored;
      _activePreview = preview;
      final reconciled = await portfolioController.refreshPortfolio(
        portfolioId,
      );
      _phase = reconciled
          ? OrderCommandPhase.restoredReview
          : OrderCommandPhase.reconciliationRequired;
      _message = reconciled
          ? 'A prior confirmation may have reached the Demo ledger. Review this exact saved preview; it will never submit automatically.'
          : 'Refresh authoritative portfolio reads before reviewing the saved command.';
    } on Object {
      await _journal.clear(operation);
      _activePreview = null;
      _protected = null;
      _phase = OrderCommandPhase.previewInvalidated;
      _message =
          'The saved preview cannot be verified. Create a fresh preview.';
    }
    notifyListeners();
  }

  Future<void> openOrder(String orderId) async {
    try {
      final value = await _repository.get(orderId);
      if (value.portfolioId != _portfolioId) {
        throw const LoadFailure(LoadPhase.forbidden);
      }
      _selectedOrder = value;
      notifyListeners();
    } on Object catch (error) {
      _mapFailure(error);
      notifyListeners();
    }
  }

  Future<bool> preview(OrderDraft draft) async {
    if (_protected != null) {
      _message = 'Resolve or explicitly discard the saved order confirmation before creating another preview.';
      notifyListeners();
      return false;
    }
    final validation = _validateDraft(draft);
    if (validation != null) {
      _message = validation;
      notifyListeners();
      return false;
    }
    _portfolioId = draft.portfolioId;
    _protected = null;
    _receipt = null;
    _phase = OrderCommandPhase.previewing;
    _message = null;
    notifyListeners();
    try {
      final value = await _repository.preview(draft);
      if (value.status != OrderPreviewStatus.active ||
          !value.expiresAt.isAfter(_now().toUtc())) {
        throw const OrderCommitFailure.stalePreview();
      }
      _activePreview = value;
      _phase = OrderCommandPhase.review;
      _message = 'Review the frozen Demo price and quantity. Nothing submits until you confirm.';
      notifyListeners();
      return true;
    } on Object catch (error) {
      _activePreview = null;
      _mapFailure(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> discardPendingCommit() async {
    if (_protected == null ||
        (_phase != OrderCommandPhase.restoredReview &&
            _phase != OrderCommandPhase.retryableFailure)) {
      return;
    }
    await _journal.clear(operation);
    _protected = null;
    _activePreview = null;
    _phase = _orders.isEmpty
        ? OrderCommandPhase.empty
        : OrderCommandPhase.listReady;
    _message = 'Saved confirmation discarded after explicit review. A new preview will use a new key.';
    notifyListeners();
  }

  Future<void> reviewRestoredCommit() async {
    if (_phase != OrderCommandPhase.restoredReview &&
        _phase != OrderCommandPhase.retryableFailure &&
        _phase != OrderCommandPhase.throttled) {
      return;
    }
    final preview = _activePreview;
    if (preview == null || !preview.expiresAt.isAfter(_now().toUtc())) {
      await _invalidatePreview(
        'The Demo preview expired. Create a fresh preview.',
      );
      return;
    }
    _phase = OrderCommandPhase.review;
    _message = 'Review the unchanged saved preview before a same-key retry.';
    notifyListeners();
  }

  Future<void> confirm() {
    final current = _commitOperation;
    if (current != null) return current;
    if (_phase != OrderCommandPhase.review || _activePreview == null) {
      return Future.value();
    }
    late final Future<void> operation;
    operation = _confirm().whenComplete(() {
      if (identical(_commitOperation, operation)) {
        _commitOperation = null;
        notifyListeners();
      }
    });
    _commitOperation = operation;
    notifyListeners();
    return operation;
  }

  Future<void> _confirm() async {
    final preview = _activePreview!;
    if (!preview.expiresAt.isAfter(_now().toUtc())) {
      await _invalidatePreview(
        'The Demo preview expired. Create a fresh preview.',
      );
      return;
    }
    final payload = <String, Object?>{
      'portfolio_id': preview.portfolioId,
      'preview_id': preview.id,
      'portfolio_version': preview.portfolioVersion,
    };
    final existing = _protected;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _invalidatePreview(
        'The command details changed. Create and review a fresh preview.',
      );
      return;
    }
    _protected = await _journal.protect(
      operation: operation,
      payload: payload,
      precondition: preview.toProtectedMap(),
      reuse: existing,
    );
    _phase = OrderCommandPhase.confirming;
    _message = null;
    notifyListeners();
    try {
      _receipt = await _repository.commit(
        OrderCommit(
          portfolioId: preview.portfolioId,
          previewId: preview.id,
          portfolioVersion: preview.portfolioVersion,
          idempotencyKey: _protected!.key,
        ),
      );
      await _journal.clear(operation);
      _protected = null;
      await _refreshAccepted(preview.portfolioId);
    } on OrderCommitFailure catch (failure) {
      if (failure.reason == OrderCommitFailureReason.stalePreview) {
        await portfolioController.refreshPortfolio(preview.portfolioId);
        await _invalidatePreview(
          'The Demo price or portfolio changed. Review a fresh preview before confirming again.',
        );
      } else {
        await _clearProtectedTerminal();
        _phase = OrderCommandPhase.terminalFailure;
        _message = 'The Demo order was rejected. Create a fresh preview.';
      }
    } on AmbiguousOrderFailure {
      final reconciled = await _reconcile(preview.portfolioId);
      _phase = reconciled
          ? OrderCommandPhase.retryableFailure
          : OrderCommandPhase.reconciliationRequired;
      _message = reconciled
          ? 'The response was lost. Review this exact saved preview before a same-key retry.'
          : 'The response was lost and authority is unavailable. Nothing will retry automatically.';
    } on OfflineException {
      final reconciled = await _reconcile(preview.portfolioId);
      _phase = reconciled
          ? OrderCommandPhase.retryableFailure
          : OrderCommandPhase.reconciliationRequired;
      _message = 'No receipt is shown. Reconcile and review before any same-key retry.';
    } on LoadFailure catch (failure) {
      if (failure.phase == LoadPhase.conflict) {
        await portfolioController.refreshPortfolio(preview.portfolioId);
        await _invalidatePreview(
          'The Demo preview is stale. Portfolio authority was refreshed; create a new preview.',
        );
      } else {
        _phase = _phaseFor(failure.phase);
        _message = failure.message;
        if (_phase == OrderCommandPhase.forbidden ||
            _phase == OrderCommandPhase.terminalFailure) {
          await _clearProtectedTerminal();
        }
      }
    }
    notifyListeners();
  }

  Future<void> retryReceiptRefresh() async {
    final portfolioId = _portfolioId;
    if (_receipt == null || portfolioId == null) return;
    await _refreshAccepted(portfolioId);
    notifyListeners();
  }

  Future<void> retryReconciliation() async {
    final portfolioId = _portfolioId;
    if (portfolioId == null) return;
    final reconciled = await _reconcile(portfolioId);
    if (reconciled) {
      _phase = OrderCommandPhase.restoredReview;
      _message = 'Authority is current. Review the exact saved preview; it will not submit automatically.';
    }
    notifyListeners();
  }

  Future<void> _refreshAccepted(String portfolioId) async {
    final portfolioReady = await portfolioController.refreshPortfolio(
      portfolioId,
    );
    final ordersReady = await _refreshOrders();
    final watermark = portfolioReady
        ? portfolioController.detailState.value?.portfolio.ledgerWatermark
        : null;
    _invalidationBus.publish(
      InvalidationEvent(
        scope: scope,
        resource: InvalidationResource.ledger,
        ledgerWatermark: watermark,
      ),
    );
    if (watermark == null || !ordersReady) {
      _phase = OrderCommandPhase.receiptRefreshPending;
      _message = 'The Demo receipt committed. Authoritative portfolio reads are still refreshing.';
    } else {
      _phase = OrderCommandPhase.receipt;
      _message = 'Demo ledger reconciled at watermark $watermark.';
    }
  }

  Future<bool> _reconcile(String portfolioId) async {
    final portfolioReady = await portfolioController.refreshPortfolio(
      portfolioId,
    );
    final ordersReady = await _refreshOrders();
    return portfolioReady && ordersReady;
  }

  Future<bool> _refreshOrders() async {
    final portfolioId = _portfolioId;
    if (portfolioId == null) return false;
    try {
      _orders = List.unmodifiable(await _repository.list(portfolioId));
      if (_protected == null && _receipt == null) {
        _phase = _orders.isEmpty
            ? OrderCommandPhase.empty
            : OrderCommandPhase.listReady;
      }
      notifyListeners();
      return true;
    } on Object catch (error) {
      if (_protected == null && _receipt == null) _mapFailure(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> _invalidatePreview(String message) async {
    await _journal.clear(operation);
    _protected = null;
    _activePreview = null;
    _phase = OrderCommandPhase.previewInvalidated;
    _message = message;
    notifyListeners();
  }

  Future<void> _clearProtectedTerminal() async {
    await _journal.clear(operation);
    _protected = null;
    _activePreview = null;
  }

  String? _validateDraft(OrderDraft draft) {
    if (draft.portfolioId.trim().isEmpty || draft.assetId.trim().isEmpty) {
      return 'Choose a Demo portfolio and asset.';
    }
    final notional = draft.notionalMinor;
    final quantity = draft.quantityValue;
    if ((notional == null) == (quantity == null)) {
      return 'Enter either a Demo USD amount or a fractional quantity.';
    }
    if (notional != null && (notional < 1 || notional > 1000000000)) {
      return 'Enter a positive Demo amount within the supported range.';
    }
    if (quantity != null &&
        (!RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,12})?$').hasMatch(quantity) ||
            (double.tryParse(quantity) ?? 0) <= 0 ||
            (draft.quantityScale ?? -1) < 0 ||
            (draft.quantityScale ?? 13) > 12)) {
      return 'Enter a positive fractional quantity with up to 12 decimals.';
    }
    return null;
  }

  void _mapFailure(Object error) {
    if (error is OrderCommitFailure &&
        error.reason == OrderCommitFailureReason.stalePreview) {
      _phase = OrderCommandPhase.previewInvalidated;
      _message = 'Create a fresh Demo preview.';
      return;
    }
    if (error is OfflineException) {
      _phase = OrderCommandPhase.retryableFailure;
      _message = 'Demo order data is offline. Nothing was submitted.';
      return;
    }
    if (error is LoadFailure) {
      _phase = _phaseFor(error.phase);
      _message = error.message;
      return;
    }
    _phase = OrderCommandPhase.terminalFailure;
    _message = 'The Demo order response is not supported by this app version.';
  }
}

OrderCommandPhase _phaseFor(LoadPhase phase) => switch (phase) {
  LoadPhase.forbidden => OrderCommandPhase.forbidden,
  LoadPhase.throttled => OrderCommandPhase.throttled,
  LoadPhase.retryableFailure => OrderCommandPhase.retryableFailure,
  LoadPhase.conflict => OrderCommandPhase.previewInvalidated,
  _ => OrderCommandPhase.terminalFailure,
};
