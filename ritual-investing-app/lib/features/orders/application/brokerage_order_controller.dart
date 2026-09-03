// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/cache/read_cache.dart';
import '../../brokerage_connection/domain/model.dart';
import '../../portfolio/application/brokerage_controller.dart';
import '../data/brokerage_repository.dart';
import '../domain/brokerage_model.dart';

enum BrokerageOrderPhase {
  idle,
  loading,
  listReady,
  empty,
  authorityBlocked,
  previewing,
  review,
  restoredReview,
  confirming,
  responseUnknown,
  commandDispatching,
  commandAccepted,
  commandAmbiguous,
  commandReconciling,
  commandResolved,
  commandFailed,
  commandManualReview,
  retryableFailure,
  throttled,
  forbidden,
  terminalFailure,
}

class BrokerageOrderController extends ChangeNotifier {
  BrokerageOrderController({
    required BrokerageOrderRepository repository,
    required this.portfolioController,
    required PendingCommandStore pendingStore,
    required CacheScope scope,
    required String Function() createKey,
    required DateTime Function() now,
  }) : _repository = repository,
       _now = now,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       );

  final BrokerageOrderRepository _repository;
  final BrokeragePortfolioController portfolioController;
  final DateTime Function() _now;
  final FinancialCommandJournal _journal;

  String? _accountId;
  BrokerageOrderPhase _phase = BrokerageOrderPhase.idle;
  BrokerageOrderListView? _orderList;
  BrokerageOrderDetailView? _selectedOrder;
  BrokerageOrderPreviewView? _activePreview;
  BrokerageOrderCommandView? _command;
  JournaledFinancialCommand? _protected;
  String? _message;
  Future<void>? _mutation;

  String? get accountId => _accountId;
  BrokerageOrderPhase get phase => _phase;
  BrokerageOrderListView? get orderList => _orderList;
  List<BrokerageOrderView> get orders => _orderList?.orders ?? const [];
  BrokerageOrderDetailView? get selectedOrder => _selectedOrder;
  BrokerageOrderPreviewView? get activePreview => _activePreview;
  BrokerageOrderCommandView? get command => _command;
  String? get message => _message;
  bool get isMutating => _mutation != null;
  bool get mutationsAvailable {
    final account = _accountId;
    final portfolio = portfolioController.state.value;
    return account != null &&
        portfolio?.accountId == account &&
        portfolio!.mutationsAvailableAt(_now());
  }

  String get authorityGateMessage {
    final snapshot = portfolioController.state.value;
    if (snapshot == null || snapshot.accountId != _accountId) {
      return 'Order entry is disabled because account authority is unavailable.';
    }
    final activeRestrictionCodes = snapshot.restrictions.value
        ?.where((restriction) => restriction.active)
        .map((restriction) => restriction.code)
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (activeRestrictionCodes != null && activeRestrictionCodes.isNotEmpty) {
      activeRestrictionCodes.sort();
      return 'Orders are disabled by active account restrictions: ${activeRestrictionCodes.join(', ')}.';
    }
    final checkedAt = _now().toUtc();
    if (snapshot.capabilities.state != BrokerageResourceState.fresh ||
        snapshot.restrictions.state != BrokerageResourceState.fresh ||
        snapshot.capabilities.expiresAt == null ||
        snapshot.restrictions.expiresAt == null ||
        !snapshot.capabilities.expiresAt!.isAfter(checkedAt) ||
        !snapshot.restrictions.expiresAt!.isAfter(checkedAt)) {
      return 'Order entry is disabled because restriction authority is stale or unavailable.';
    }
    return 'Order entry is disabled because manual-order capability is unavailable.';
  }

  String _operation(String accountId) => 'webull-order-command:$accountId';

  Future<void> openAccount(String accountId) async {
    if (_accountId != accountId) {
      _accountId = accountId;
      _phase = BrokerageOrderPhase.loading;
      _orderList = null;
      _selectedOrder = null;
      _activePreview = null;
      _command = null;
      _protected = null;
      _message = null;
      notifyListeners();
    }
    await refreshOrders();
    final restored = await _journal.restore(_operation(accountId));
    if (restored == null) {
      _applyAuthorityGate();
      return;
    }
    try {
      final preview = BrokerageOrderPreviewView.fromProtectedMap(
        restored.precondition,
      );
      if (preview.accountId != accountId ||
          !preview.isActiveAt(_now()) ||
          !_reviewedHash.hasMatch(preview.reviewedPayloadHash)) {
        await _journal.clear(_operation(accountId));
        _phase = BrokerageOrderPhase.authorityBlocked;
        _message = 'The saved Webull preview expired. Refresh account authority and create a new preview.';
      } else {
        _protected = restored;
        _activePreview = preview;
        _phase = BrokerageOrderPhase.restoredReview;
        _message = 'A prior confirmation may have reached Webull. Review this exact saved command; it will never resubmit automatically.';
      }
    } on Object {
      await _journal.clear(_operation(accountId));
      _phase = BrokerageOrderPhase.terminalFailure;
      _message = 'The saved command cannot be verified and was removed from this device.';
    }
    notifyListeners();
  }

  Future<void> refreshOrders({bool authoritative = false}) async {
    final account = _accountId;
    if (account == null) return;
    final prior = _orderList;
    if (prior == null) _phase = BrokerageOrderPhase.loading;
    notifyListeners();
    try {
      final value = await _repository.list(account, refresh: authoritative);
      if (_accountId != account) return;
      _orderList = value;
      _phase = value.orders.isEmpty
          ? BrokerageOrderPhase.empty
          : BrokerageOrderPhase.listReady;
      _message = _collectionMessage(value);
    } on BrokerageOrderFailure catch (failure) {
      if (_accountId != account) return;
      _orderList = prior;
      _mapFailure(failure, preserveReview: true);
    }
    notifyListeners();
  }

  Future<void> openOrder(String orderId) async {
    final account = _accountId;
    if (account == null) return;
    try {
      final value = await _repository.get(account, orderId);
      if (_accountId != account || value.order.id != orderId) return;
      _selectedOrder = value;
      _message = null;
    } on BrokerageOrderFailure catch (failure) {
      _mapFailure(failure, preserveReview: true);
    }
    notifyListeners();
  }

  Future<bool> previewPlace(BrokeragePlaceOrderIntent intent) async {
    final account = _accountId;
    if (account == null || !_canBeginMutation(account)) return false;
    final validation = _validatePlace(intent);
    if (validation != null) {
      _message = validation;
      notifyListeners();
      return false;
    }
    _phase = BrokerageOrderPhase.previewing;
    _message = null;
    notifyListeners();
    try {
      final value = await _repository.previewPlace(account, intent);
      if (_accountId != account ||
          !value.isActiveAt(_now()) ||
          !_reviewedHash.hasMatch(value.reviewedPayloadHash)) {
        throw const BrokerageOrderFailure(
          BrokerageOrderFailureReason.stalePreview,
        );
      }
      _activePreview = value;
      _command = null;
      _phase = BrokerageOrderPhase.review;
      _message = 'Review the exact Webull order fields. Nothing is sent until you confirm.';
      notifyListeners();
      return true;
    } on BrokerageOrderFailure catch (failure) {
      _activePreview = null;
      _mapFailure(failure);
      notifyListeners();
      return false;
    }
  }

  Future<bool> previewModify(
    String orderId,
    BrokerageModifyOrderIntent intent,
  ) {
    if (!_wholeQuantity.hasMatch(intent.quantity) ||
        (intent.limitPrice != null &&
            (!_positiveDecimal.hasMatch(intent.limitPrice!) ||
                intent.limitPrice == '0'))) {
      _message = 'Enter a positive whole-share quantity and valid limit price.';
      notifyListeners();
      return Future.value(false);
    }
    return _previewExisting(
      orderId,
      () => _repository.previewModify(_accountId!, orderId, intent),
    );
  }

  Future<bool> previewCancel(String orderId) => _previewExisting(
    orderId,
    () => _repository.previewCancel(_accountId!, orderId),
  );

  Future<bool> _previewExisting(
    String orderId,
    Future<BrokerageOrderPreviewView> Function() request,
  ) async {
    final account = _accountId;
    if (account == null || !_canBeginMutation(account)) return false;
    final order = _selectedOrder?.order;
    if (order == null || order.id != orderId || !order.canChange) {
      _message = 'Refresh the Webull order before requesting a change or cancellation.';
      notifyListeners();
      return false;
    }
    _phase = BrokerageOrderPhase.previewing;
    _message = null;
    notifyListeners();
    try {
      final value = await request();
      if (_accountId != account ||
          !value.isActiveAt(_now()) ||
          !_reviewedHash.hasMatch(value.reviewedPayloadHash)) {
        throw const BrokerageOrderFailure(
          BrokerageOrderFailureReason.stalePreview,
        );
      }
      _activePreview = value;
      _command = null;
      _phase = BrokerageOrderPhase.review;
      _message = 'Review the exact provider change. A later fill can supersede this request.';
      notifyListeners();
      return true;
    } on BrokerageOrderFailure catch (failure) {
      _activePreview = null;
      _mapFailure(failure);
      notifyListeners();
      return false;
    }
  }

  Future<void> reviewRestoredCommand() async {
    if (_phase != BrokerageOrderPhase.restoredReview &&
        _phase != BrokerageOrderPhase.responseUnknown &&
        _phase != BrokerageOrderPhase.throttled) {
      return;
    }
    final preview = _activePreview;
    if (preview == null || !preview.isActiveAt(_now())) {
      await _invalidatePreview();
      return;
    }
    _phase = BrokerageOrderPhase.review;
    _message = 'Review the unchanged saved command before an explicit same-key confirmation.';
    notifyListeners();
  }

  Future<void> confirm() {
    final current = _mutation;
    if (current != null) return current;
    if (_phase != BrokerageOrderPhase.review || _activePreview == null) {
      return Future.value();
    }
    late final Future<void> operation;
    operation = _confirm().whenComplete(() {
      if (identical(_mutation, operation)) {
        _mutation = null;
        notifyListeners();
      }
    });
    _mutation = operation;
    notifyListeners();
    return operation;
  }

  Future<void> _confirm() async {
    final preview = _activePreview!;
    if (!preview.isActiveAt(_now())) {
      await _invalidatePreview();
      return;
    }
    if (!mutationsAvailable) {
      _phase = BrokerageOrderPhase.authorityBlocked;
      _message = 'Webull capability or restriction authority is no longer fresh. Refresh before creating a new preview.';
      notifyListeners();
      return;
    }
    final payload = _reviewedPayload(preview);
    final existing = _protected;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _invalidatePreview();
      return;
    }
    _protected = await _journal.protect(
      operation: _operation(preview.accountId),
      payload: payload,
      precondition: preview.toProtectedMap(),
      reuse: existing,
    );
    _phase = BrokerageOrderPhase.confirming;
    _message = null;
    notifyListeners();
    try {
      final command = switch (preview.operation) {
        BrokerageOrderOperation.place => await _repository.confirmPlace(
          preview: preview,
          idempotencyKey: _protected!.key,
        ),
        BrokerageOrderOperation.modify => await _repository.confirmModify(
          preview: preview,
          intent: preview.modifyIntent!,
          idempotencyKey: _protected!.key,
        ),
        BrokerageOrderOperation.cancel => await _repository.confirmCancel(
          preview: preview,
          idempotencyKey: _protected!.key,
        ),
      };
      _command = command;
      await _applyCommand(command);
    } on BrokerageOrderFailure catch (failure) {
      if (failure.reason == BrokerageOrderFailureReason.stalePreview ||
          failure.reason == BrokerageOrderFailureReason.staleAuthority) {
        await _invalidatePreview();
        _message = 'The reviewed authority changed. Refresh Webull and create a new preview.';
      } else if (failure.reason == BrokerageOrderFailureReason.offline ||
          failure.reason == BrokerageOrderFailureReason.unavailable) {
        _phase = BrokerageOrderPhase.responseUnknown;
        _message = 'No command result is shown. Nothing retries automatically; review this exact saved command before any same-key confirmation.';
      } else {
        _mapFailure(failure, preserveReview: true);
      }
    }
    notifyListeners();
  }

  Future<void> refreshCommand() async {
    final current = _command;
    if (current == null) return;
    try {
      final value = await _repository.getCommand(current.id);
      if (value.accountId != _accountId) return;
      _command = value;
      await _applyCommand(value);
    } on BrokerageOrderFailure catch (failure) {
      _mapFailure(failure, preserveReview: true);
    }
    notifyListeners();
  }

  Future<void> _applyCommand(BrokerageOrderCommandView value) async {
    final phase = switch (value.state) {
      BrokerageProviderCommandState.dispatching =>
        BrokerageOrderPhase.commandDispatching,
      BrokerageProviderCommandState.accepted =>
        BrokerageOrderPhase.commandAccepted,
      BrokerageProviderCommandState.ambiguous =>
        BrokerageOrderPhase.commandAmbiguous,
      BrokerageProviderCommandState.reconciling =>
        BrokerageOrderPhase.commandReconciling,
      BrokerageProviderCommandState.resolved =>
        BrokerageOrderPhase.commandResolved,
      BrokerageProviderCommandState.failed => BrokerageOrderPhase.commandFailed,
      BrokerageProviderCommandState.manualReview ||
      BrokerageProviderCommandState.unknown =>
        BrokerageOrderPhase.commandManualReview,
    };
    final message = _commandMessage(value);
    _phase = phase;
    _message = message;
    if (value.isTerminal) {
      await _journal.clear(_operation(value.accountId));
      _protected = null;
      _activePreview = null;
      await refreshOrders(authoritative: true);
      if (value.orderId case final orderId?) await openOrder(orderId);
      _phase = phase;
      _message = message;
    }
  }

  bool _canBeginMutation(String account) {
    if (_protected != null || (_command?.ambiguous ?? false)) {
      _message = 'Resolve the earlier account command before starting another Webull order action.';
      notifyListeners();
      return false;
    }
    if (!mutationsAvailable) {
      _phase = BrokerageOrderPhase.authorityBlocked;
      _message = 'Manual orders require fresh Webull capabilities and restrictions for this account.';
      notifyListeners();
      return false;
    }
    return _accountId == account;
  }

  void _applyAuthorityGate() {
    if (!mutationsAvailable &&
        (_phase == BrokerageOrderPhase.listReady ||
            _phase == BrokerageOrderPhase.empty)) {
      _phase = BrokerageOrderPhase.authorityBlocked;
      _message = 'Order history may remain visible, but mutations require fresh Webull authority.';
      notifyListeners();
    }
  }

  Future<void> _invalidatePreview() async {
    final account = _accountId;
    if (account != null) await _journal.clear(_operation(account));
    _protected = null;
    _activePreview = null;
    _phase = BrokerageOrderPhase.authorityBlocked;
    _message = 'The saved preview is no longer valid. Refresh Webull and create a new preview.';
    notifyListeners();
  }

  void _mapFailure(
    BrokerageOrderFailure failure, {
    bool preserveReview = false,
  }) {
    _phase = switch (failure.reason) {
      BrokerageOrderFailureReason.offline ||
      BrokerageOrderFailureReason.unavailable =>
        BrokerageOrderPhase.retryableFailure,
      BrokerageOrderFailureReason.staleAuthority ||
      BrokerageOrderFailureReason.stalePreview ||
      BrokerageOrderFailureReason.ambiguityBlocked =>
        BrokerageOrderPhase.authorityBlocked,
      BrokerageOrderFailureReason.forbidden => BrokerageOrderPhase.forbidden,
      BrokerageOrderFailureReason.throttled => BrokerageOrderPhase.throttled,
      BrokerageOrderFailureReason.invalid =>
        BrokerageOrderPhase.terminalFailure,
    };
    if (!preserveReview) _activePreview = null;
    _message =
        failure.message ??
        switch (failure.reason) {
          BrokerageOrderFailureReason.offline =>
            'Webull is offline. No financial command will retry automatically.',
          BrokerageOrderFailureReason.staleAuthority =>
            'Refresh Webull capabilities and restrictions before ordering.',
          BrokerageOrderFailureReason.stalePreview =>
            'That preview expired or changed. Create a new preview.',
          BrokerageOrderFailureReason.ambiguityBlocked =>
            'An earlier command for this account is still ambiguous.',
          BrokerageOrderFailureReason.forbidden =>
            'This Webull account is not available to the current member.',
          BrokerageOrderFailureReason.throttled =>
            'Webull is rate limited. Wait, then explicitly refresh.',
          BrokerageOrderFailureReason.unavailable =>
            'Webull order service is temporarily unavailable.',
          BrokerageOrderFailureReason.invalid =>
            'This order response is not supported by this app version.',
        };
  }
}

Map<String, Object?> _reviewedPayload(BrokerageOrderPreviewView preview) => {
  'account_id': preview.accountId,
  'preview_id': preview.id,
  'operation': preview.operation.name,
  'target_order_id': preview.targetOrderId,
  'reviewed_payload_hash': preview.reviewedPayloadHash,
  'place_intent': preview.placeIntent?.toCanonicalMap(),
  'modify_intent': preview.modifyIntent?.toCanonicalMap(),
};

String? _validatePlace(BrokeragePlaceOrderIntent value) {
  if (value.instrumentId.trim().isEmpty || value.symbol.trim().isEmpty) {
    return 'Choose a supported Webull instrument.';
  }
  if (!_wholeQuantity.hasMatch(value.quantity)) {
    return 'Enter a positive whole-share quantity.';
  }
  if (value.timeInForce != BrokerageTimeInForce.day) {
    return 'The current Webull policy supports day orders only.';
  }
  if (value.orderType == BrokerageOrderType.limit &&
      (value.limitPrice == null ||
          !_positiveDecimal.hasMatch(value.limitPrice!) ||
          value.limitPrice == '0')) {
    return 'Enter a positive limit price.';
  }
  if (value.orderType == BrokerageOrderType.market &&
      value.limitPrice != null) {
    return 'Market orders cannot include a limit price.';
  }
  return null;
}

String? _collectionMessage(BrokerageOrderListView value) =>
    switch (value.state) {
      BrokerageOrderCollectionState.fresh ||
      BrokerageOrderCollectionState.empty => null,
      BrokerageOrderCollectionState.stale =>
        'Showing timestamped Webull orders that may be stale.',
      BrokerageOrderCollectionState.partial =>
        'Webull returned a partial order history. Mutations remain gated.',
      BrokerageOrderCollectionState.offline =>
        'Showing cached Webull orders while offline.',
      BrokerageOrderCollectionState.rateLimited =>
        'Showing the last Webull order history while refresh is rate limited.',
      BrokerageOrderCollectionState.reauthorizationRequired =>
        'Reconnect Webull to refresh order history.',
      BrokerageOrderCollectionState.disconnected =>
        'Connect Webull to view order history.',
      BrokerageOrderCollectionState.unavailable ||
      BrokerageOrderCollectionState.unknown =>
        'Webull order history is unavailable.',
    };

String _commandMessage(
  BrokerageOrderCommandView value,
) => switch (value.state) {
  BrokerageProviderCommandState.dispatching => 'The command is persisted and dispatch has started. Do not submit another order.',
  BrokerageProviderCommandState.accepted => 'Webull acknowledged the command. The order remains nonterminal until provider state resolves.',
  BrokerageProviderCommandState.ambiguous => 'The provider outcome is ambiguous. New mutations for this account are blocked.',
  BrokerageProviderCommandState.reconciling => 'Leo is reconciling by the original provider identifier; it is not resubmitting the order.',
  BrokerageProviderCommandState.resolved =>
    'The command resolved from authoritative Webull evidence.',
  BrokerageProviderCommandState.failed =>
    'The provider rejected or failed this command. No success was invented.',
  BrokerageProviderCommandState.manualReview =>
    'The command needs staff review. Do not submit another account mutation.',
  BrokerageProviderCommandState.unknown =>
    'This command state is unknown. New mutations remain disabled.',
};

final _positiveDecimal = RegExp(r'^(?:0|[1-9]\d{0,37})(?:\.\d{1,18})?$');
final _wholeQuantity = RegExp(r'^[1-9]\d{0,37}$');
final _reviewedHash = RegExp(r'^[a-f0-9]{64}$');
