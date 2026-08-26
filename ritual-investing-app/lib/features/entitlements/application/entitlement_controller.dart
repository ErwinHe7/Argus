// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/read_cache.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum EntitlementPhase {
  idle,
  loading,
  ready,
  stale,
  upgradeReview,
  creating,
  checkoutReview,
  confirming,
  receipt,
  downgradeReview,
  restoredReview,
  reconciliationRequired,
  expired,
  conflictReview,
  forbidden,
  throttled,
  retryableFailure,
  terminalFailure,
}

enum _MembershipOperation { create, confirm, restore, downgrade }

class EntitlementController extends ChangeNotifier {
  EntitlementController({
    required EntitlementRepository repository,
    required PendingCommandStore pendingStore,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
    MemberPersonalization personalization = const MemberPersonalization(),
    Future<void> Function()? onAuthorityTransition,
  }) : _repository = repository,
       _now = now,
       _personalization = personalization,
       _onAuthorityTransition = onAuthorityTransition,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       );

  final EntitlementRepository _repository;
  final DateTime Function() _now;
  final FinancialCommandJournal _journal;
  final CacheScope scope;
  Future<void> Function()? _onAuthorityTransition;
  MemberPersonalization _personalization;
  EntitlementPhase _phase = EntitlementPhase.idle;
  List<DemoPlan> _plans = const [];
  DemoEntitlement? _entitlement;
  DemoCheckout? _checkout;
  MembershipReturnContext? _returnContext;
  JournaledFinancialCommand? _protectedCommand;
  _MembershipOperation? _protectedOperation;
  String? _message;
  bool _isFresh = false;
  bool _mutating = false;

  EntitlementPhase get phase => _phase;
  List<DemoPlan> get plans => List.unmodifiable(_plans);
  DemoEntitlement? get entitlement => _entitlement;
  DemoCheckout? get checkout => _checkout;
  MembershipReturnContext? get returnContext => _returnContext;
  String? get message => _message;
  bool get isFresh => _isFresh;
  bool get hasProtectedCommand => _protectedCommand != null;
  bool get canConfirmCheckout => _checkout?.isOpenAt(_now()) ?? false;
  bool get canReviewProtectedCommand =>
      _protectedCommand != null &&
      {
        EntitlementPhase.restoredReview,
        EntitlementPhase.retryableFailure,
        EntitlementPhase.throttled,
        EntitlementPhase.conflictReview,
      }.contains(_phase);

  String get explanationLabel {
    final voice = switch (_personalization.ritualVoice) {
      MemberRitualVoice.mystical => 'Symbolic',
      MemberRitualVoice.practical => 'Practical',
      MemberRitualVoice.balanced || MemberRitualVoice.unavailable => 'Balanced',
    };
    final depth = switch (_personalization.explanationDepth) {
      MemberExplanationDepth.beginner => 'step-by-step',
      MemberExplanationDepth.guided => 'guided',
      MemberExplanationDepth.advanced => 'concise',
      MemberExplanationDepth.unavailable => 'standard',
    };
    return '$voice · $depth explanation';
  }

  void bindAuthorityTransition(Future<void> Function() refresh) {
    _onAuthorityTransition = refresh;
  }

  void updatePersonalization(MemberPersonalization value) {
    if (_personalization.explanationDepth == value.explanationDepth &&
        _personalization.ritualVoice == value.ritualVoice) {
      return;
    }
    _personalization = value;
    notifyListeners();
  }

  CapabilityGateResult gate(DemoCapability capability) =>
      _gateKnown(capability);

  CapabilityGateResult gateCode(String capabilityCode) {
    final capability = DemoCapability.fromCode(capabilityCode);
    return capability == null
        ? const CapabilityGateResult(CapabilityGateReason.unknownCapability)
        : _gateKnown(capability);
  }

  bool canUpgrade(DemoCapability capability) {
    if (!_isFresh || gate(capability).isAllowed) return false;
    final premium = _plans
        .where((plan) => plan.code == DemoPlanCode.premiumDemo)
        .toList(growable: false);
    return premium.length == 1 && premium.single.includes(capability);
  }

  bool acceptsReturnContext(DemoCapability capability, String location) =>
      _validReturnContext(capability, location);

  CapabilityGateResult _gateKnown(DemoCapability capability) {
    if (_phase == EntitlementPhase.idle || _phase == EntitlementPhase.loading) {
      return const CapabilityGateResult(CapabilityGateReason.loading);
    }
    if (!_isFresh) {
      return const CapabilityGateResult(CapabilityGateReason.staleAuthority);
    }
    final entitlement = _entitlement;
    if (entitlement == null ||
        entitlement.status != DemoEntitlementStatus.active) {
      return const CapabilityGateResult(
        CapabilityGateReason.inactiveEntitlement,
      );
    }
    final matching = _plans
        .where((plan) => plan.code == entitlement.planCode)
        .toList(growable: false);
    if (matching.length != 1) {
      return const CapabilityGateResult(CapabilityGateReason.unknownPlan);
    }
    return CapabilityGateResult(
      matching.single.includes(capability)
          ? CapabilityGateReason.allowed
          : CapabilityGateReason.capabilityUnavailable,
    );
  }

  Future<void> load({bool preserveValue = false}) async {
    if (!preserveValue) {
      _phase = EntitlementPhase.loading;
      _message = null;
      notifyListeners();
    }
    final refreshed = await _refreshAuthority();
    if (refreshed) {
      await _restoreProtectedCommand();
      if (_protectedCommand == null &&
          _phase != EntitlementPhase.receipt &&
          _phase != EntitlementPhase.checkoutReview &&
          _phase != EntitlementPhase.expired) {
        _phase = EntitlementPhase.ready;
      }
    }
    notifyListeners();
  }

  void prepareCheckout({
    required DemoCapability capability,
    required String returnLocation,
  }) {
    if (_mutating || _protectedCommand != null) return;
    if (!_validReturnContext(capability, returnLocation)) {
      _phase = EntitlementPhase.terminalFailure;
      _message = 'That return destination is not a supported member route.';
      notifyListeners();
      return;
    }
    final premium = _plans
        .where((plan) => plan.code == DemoPlanCode.premiumDemo)
        .firstOrNull;
    if (!_isFresh ||
        premium == null ||
        !premium.includes(capability) ||
        gate(capability).isAllowed) {
      _message = gate(capability).isAllowed
          ? '${capability.displayName} is already included.'
          : 'Fresh Demo plan authority is required before review.';
      notifyListeners();
      return;
    }
    _returnContext = MembershipReturnContext(
      capability: capability,
      location: returnLocation,
    );
    _checkout = null;
    _phase = EntitlementPhase.upgradeReview;
    _message =
        'Review server-provided Demo access. No purchase or charge occurs.';
    notifyListeners();
  }

  Future<void> createCheckout() => _runMutation(() async {
    final context = _returnContext;
    final restoring = _protectedOperation == _MembershipOperation.create;
    if (context == null ||
        (!restoring && _phase != EntitlementPhase.upgradeReview) ||
        (restoring &&
            _phase != EntitlementPhase.upgradeReview &&
            _phase != EntitlementPhase.restoredReview)) {
      return;
    }
    final payload = <String, Object?>{
      'plan_code': DemoPlanCode.premiumDemo.wireValue,
    };
    final precondition = <String, Object?>{
      ...context.toJson(),
      'plan_code': DemoPlanCode.premiumDemo.wireValue,
    };
    final existing = _protectedCommand;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _clearProtected();
      _terminalMessage('The protected Demo checkout changed and was cleared.');
      return;
    }
    _protectedCommand = await _journal.protect(
      operation: _operationName(_MembershipOperation.create),
      payload: payload,
      precondition: precondition,
      reuse: existing,
    );
    _protectedOperation = _MembershipOperation.create;
    _phase = EntitlementPhase.creating;
    _message = null;
    notifyListeners();
    try {
      final result = await _repository.createCheckout(
        DemoPlanCode.premiumDemo.wireValue,
        _protectedCommand!.key,
      );
      if (result.planCode != DemoPlanCode.premiumDemo) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      _checkout = result;
      if (result.isOpenAt(_now())) {
        await _clearProtected();
        _applyCheckoutState(result);
      } else {
        await _reconcileKnownCheckout(result.id);
      }
    } on AmbiguousEntitlementMutation {
      await _reconcileCreate();
    } on Object catch (error) {
      await _mapCommandFailure(error);
    }
    notifyListeners();
  });

  Future<void> openCheckout(String sessionId) async {
    _phase = EntitlementPhase.loading;
    _message = null;
    notifyListeners();
    try {
      final result = await _repository.getCheckout(sessionId);
      _checkout = result;
      if (result.status == DemoCheckoutStatus.completed) {
        await _finishConfirmedCheckout(result);
      } else {
        await _refreshAuthority();
        _applyCheckoutState(result);
      }
    } on Object catch (error) {
      _mapReadFailure(error);
    }
    notifyListeners();
  }

  Future<void> confirmCheckout() => _runMutation(() async {
    final session = _checkout;
    if (session == null ||
        (!session.isOpenAt(_now()) &&
            session.status != DemoCheckoutStatus.completed)) {
      if (session != null) _applyCheckoutState(session);
      notifyListeners();
      return;
    }
    if (session.status == DemoCheckoutStatus.completed) {
      await _finishConfirmedCheckout(session);
      notifyListeners();
      return;
    }
    final payload = <String, Object?>{
      'session_id': session.id,
      'version': session.version,
    };
    final context = _returnContext;
    final precondition = <String, Object?>{
      ...payload,
      if (context != null) ...context.toJson(),
    };
    final existing = _protectedOperation == _MembershipOperation.confirm
        ? _protectedCommand
        : null;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _clearProtected();
      _terminalMessage(
        'The protected confirmation no longer matches this session.',
      );
      return;
    }
    _protectedCommand = await _journal.protect(
      operation: _operationName(_MembershipOperation.confirm),
      payload: payload,
      precondition: precondition,
      reuse: existing,
    );
    _protectedOperation = _MembershipOperation.confirm;
    _phase = EntitlementPhase.confirming;
    _message = null;
    notifyListeners();
    try {
      await _repository.confirmCheckout(
        session.id,
        session.version,
        _protectedCommand!.key,
      );
      await _reconcileConfirm();
    } on AmbiguousEntitlementMutation {
      await _reconcileConfirm();
    } on Object catch (error) {
      if (error is LoadFailure && error.phase == LoadPhase.conflict) {
        await _reconcileConfirm();
      } else {
        await _mapCommandFailure(error);
      }
    }
    notifyListeners();
  });

  void cancelCheckout() {
    if (_mutating || _protectedCommand != null) return;
    _checkout = null;
    _returnContext = null;
    _phase = _isFresh ? EntitlementPhase.ready : EntitlementPhase.stale;
    _message = 'Demo checkout abandoned locally. No purchase, charge, or provider cancellation occurred.';
    notifyListeners();
  }

  Future<void> restore() => _runMutation(() async {
    if (!_isFresh || _protectedCommand != null) return;
    const payload = <String, Object?>{};
    _protectedCommand = await _journal.protect(
      operation: _operationName(_MembershipOperation.restore),
      payload: payload,
      precondition: payload,
    );
    _protectedOperation = _MembershipOperation.restore;
    _phase = EntitlementPhase.confirming;
    notifyListeners();
    try {
      await _repository.restore(_protectedCommand!.key);
      await _reconcileRestore();
    } on AmbiguousEntitlementMutation {
      await _reconcileRestore();
    } on Object catch (error) {
      await _mapCommandFailure(error);
    }
    notifyListeners();
  });

  void prepareDowngrade() {
    if (_mutating || _protectedCommand != null || !_isFresh) return;
    final entitlement = _entitlement;
    if (entitlement == null ||
        entitlement.status != DemoEntitlementStatus.active ||
        entitlement.planCode != DemoPlanCode.premiumDemo) {
      _message = 'There is no active premium Demo access to downgrade.';
      notifyListeners();
      return;
    }
    _phase = EntitlementPhase.downgradeReview;
    _message = 'Review downgrade to free Demo access. Saved feature state is retained.';
    notifyListeners();
  }

  Future<void> confirmDowngrade() => _runMutation(() async {
    final current = _entitlement;
    final restoring = _protectedOperation == _MembershipOperation.downgrade;
    if (current == null ||
        current.planCode != DemoPlanCode.premiumDemo ||
        (!restoring && _phase != EntitlementPhase.downgradeReview)) {
      return;
    }
    final payload = <String, Object?>{
      'entitlement_id': current.id,
      'version': current.version,
    };
    final existing = restoring ? _protectedCommand : null;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _clearProtected();
      _phase = EntitlementPhase.conflictReview;
      _message = 'Entitlement authority changed. Review a new downgrade.';
      return;
    }
    _protectedCommand = await _journal.protect(
      operation: _operationName(_MembershipOperation.downgrade),
      payload: payload,
      precondition: payload,
      reuse: existing,
    );
    _protectedOperation = _MembershipOperation.downgrade;
    _phase = EntitlementPhase.confirming;
    notifyListeners();
    try {
      await _repository.downgrade(current.version, _protectedCommand!.key);
      await _reconcileDowngrade(current);
    } on AmbiguousEntitlementMutation {
      await _reconcileDowngrade(current);
    } on Object catch (error) {
      if (error is LoadFailure && error.phase == LoadPhase.conflict) {
        await _reconcileDowngrade(current);
      } else {
        await _mapCommandFailure(error);
      }
    }
    notifyListeners();
  });

  void reviewProtectedCommand() {
    if (!canReviewProtectedCommand) return;
    _phase = switch (_protectedOperation) {
      _MembershipOperation.create => EntitlementPhase.upgradeReview,
      _MembershipOperation.confirm => EntitlementPhase.checkoutReview,
      _MembershipOperation.downgrade => EntitlementPhase.downgradeReview,
      _MembershipOperation.restore || null => EntitlementPhase.restoredReview,
    };
    _message = 'Review the unchanged saved Demo command before same-key retry.';
    notifyListeners();
  }

  Future<void> retryReconciliation() async {
    if (_phase != EntitlementPhase.reconciliationRequired ||
        _protectedOperation == null) {
      return;
    }
    switch (_protectedOperation!) {
      case _MembershipOperation.create:
        await _reconcileCreate();
      case _MembershipOperation.confirm:
        await _reconcileConfirm();
      case _MembershipOperation.restore:
        await _reconcileRestore();
      case _MembershipOperation.downgrade:
        final baseline = _baselineEntitlement();
        if (baseline == null) {
          _terminalMessage('The protected entitlement snapshot is invalid.');
        } else {
          await _reconcileDowngrade(baseline);
        }
    }
    notifyListeners();
  }

  Future<void> discardProtectedCommand() async {
    if (_protectedCommand == null ||
        !{
          EntitlementPhase.restoredReview,
          EntitlementPhase.retryableFailure,
          EntitlementPhase.throttled,
          EntitlementPhase.conflictReview,
        }.contains(_phase)) {
      return;
    }
    final operation = _protectedOperation;
    final fresh = await _refreshAuthority();
    if (!fresh) return;
    var safe = false;
    switch (operation) {
      case _MembershipOperation.create:
        safe = _entitlement?.planCode != DemoPlanCode.premiumDemo;
      case _MembershipOperation.confirm:
        try {
          final exact = await _repository.getCheckout(
            _protectedCommand!.precondition['session_id']! as String,
          );
          safe =
              exact.status == DemoCheckoutStatus.open &&
              _entitlement?.planCode != DemoPlanCode.premiumDemo;
        } on Object {
          safe = false;
        }
      case _MembershipOperation.restore:
        safe = _entitlement?.status == DemoEntitlementStatus.active;
      case _MembershipOperation.downgrade:
        safe = _entitlement?.planCode == DemoPlanCode.premiumDemo;
      case null:
        safe = false;
    }
    if (!safe) {
      _phase = EntitlementPhase.reconciliationRequired;
      _message =
          'Fresh authority cannot prove this saved command is safe to abandon.';
      notifyListeners();
      return;
    }
    await _clearProtected();
    _phase = EntitlementPhase.ready;
    _message = 'Saved retry abandoned locally. No provider was contacted.';
    notifyListeners();
  }

  Future<void> _reconcileCreate() async {
    final fresh = await _refreshAuthority();
    if (!fresh) {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'Checkout authority is unavailable. Nothing will retry automatically.';
      return;
    }
    if (_entitlement?.planCode == DemoPlanCode.premiumDemo &&
        _entitlement?.status == DemoEntitlementStatus.active) {
      await _clearProtected();
      _phase = EntitlementPhase.receipt;
      _message = 'Premium Demo access is already authoritative.';
      return;
    }
    _phase = EntitlementPhase.restoredReview;
    _message = 'The create response was lost. Review the unchanged same-key retry; nothing submitted automatically.';
  }

  Future<void> _reconcileConfirm() async {
    final command = _protectedCommand;
    final sessionId = command?.precondition['session_id'];
    if (sessionId is! String) {
      _terminalMessage('The protected confirmation snapshot is invalid.');
      return;
    }
    try {
      final exact = await _repository.getCheckout(sessionId);
      _checkout = exact;
      final fresh = await _refreshAuthority();
      if (!fresh) {
        _phase = EntitlementPhase.reconciliationRequired;
        _message = 'Entitlement authority is unavailable. Nothing will retry automatically.';
        return;
      }
      if (exact.status == DemoCheckoutStatus.completed &&
          _entitlement?.status == DemoEntitlementStatus.active &&
          _entitlement?.planCode == DemoPlanCode.premiumDemo) {
        await _clearProtected();
        await _afterTransition();
        _phase = EntitlementPhase.receipt;
        _message = 'Demo confirmation reconciled once. No charge occurred.';
      } else if (exact.isOpenAt(_now()) &&
          _entitlement?.planCode != DemoPlanCode.premiumDemo) {
        _phase = EntitlementPhase.restoredReview;
        _message = 'The response was lost. Review the unchanged confirmation before a same-key retry.';
      } else if (exact.status == DemoCheckoutStatus.expired ||
          exact.status == DemoCheckoutStatus.cancelled ||
          !exact.expiresAt.isAfter(_now().toUtc())) {
        await _clearProtected();
        _phase = EntitlementPhase.expired;
        _message = 'This Demo checkout is no longer open. No charge occurred.';
      } else {
        _phase = EntitlementPhase.reconciliationRequired;
        _message = 'Checkout and entitlement authority do not yet agree.';
      }
    } on Object {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'Exact checkout authority is unavailable. Nothing will retry automatically.';
    }
  }

  Future<void> _reconcileKnownCheckout(String sessionId) async {
    try {
      final exact = await _repository.getCheckout(sessionId);
      _checkout = exact;
      if (exact.status == DemoCheckoutStatus.completed) {
        await _finishConfirmedCheckout(exact);
      } else if (exact.isOpenAt(_now())) {
        await _clearProtected();
        _applyCheckoutState(exact);
      } else {
        await _clearProtected();
        _applyCheckoutState(exact);
      }
    } on Object {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'Exact checkout authority is unavailable. Nothing will retry automatically.';
    }
  }

  Future<void> _reconcileRestore() async {
    final fresh = await _refreshAuthority();
    if (!fresh) {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'Entitlement authority is unavailable. Nothing will retry automatically.';
      return;
    }
    if (_entitlement?.status == DemoEntitlementStatus.active) {
      await _clearProtected();
      await _afterTransition();
      _phase = EntitlementPhase.ready;
      _message = 'Demo access restored from Ritual server history. No store was contacted.';
    } else {
      _phase = EntitlementPhase.restoredReview;
      _message = 'Review the saved restore before a same-key retry.';
    }
  }

  Future<void> _reconcileDowngrade(DemoEntitlement baseline) async {
    final fresh = await _refreshAuthority();
    if (!fresh) {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'Entitlement authority is unavailable. Nothing will retry automatically.';
      return;
    }
    final current = _entitlement;
    if (current?.status == DemoEntitlementStatus.active &&
        current?.planCode == DemoPlanCode.free) {
      await _clearProtected();
      await _afterTransition();
      _phase = EntitlementPhase.ready;
      _message = 'Downgraded to free Demo access. No refund or provider action exists.';
    } else if (current?.id == baseline.id &&
        current?.version == baseline.version &&
        current?.planCode == DemoPlanCode.premiumDemo) {
      _phase = EntitlementPhase.restoredReview;
      _message = 'Review the unchanged downgrade before a same-key retry.';
    } else {
      await _clearProtected();
      _phase = EntitlementPhase.conflictReview;
      _message = 'Entitlement authority changed. Review a new downgrade.';
    }
  }

  Future<void> _finishConfirmedCheckout(DemoCheckout session) async {
    final fresh = await _refreshAuthority();
    if (fresh &&
        session.status == DemoCheckoutStatus.completed &&
        _entitlement?.planCode == DemoPlanCode.premiumDemo &&
        _entitlement?.status == DemoEntitlementStatus.active) {
      await _clearProtected();
      await _afterTransition();
      _phase = EntitlementPhase.receipt;
      _message =
          'Premium Demo access confirmed. No purchase or charge occurred.';
    } else {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'Fresh entitlement authority is required before receipt.';
    }
  }

  void _applyCheckoutState(DemoCheckout value) {
    if (value.status == DemoCheckoutStatus.completed) {
      _phase = EntitlementPhase.reconciliationRequired;
      _message = 'A completed checkout still needs fresh premium entitlement authority before receipt.';
    } else if (!value.isOpenAt(_now())) {
      _phase = EntitlementPhase.expired;
      _message =
          'This Demo checkout is expired or cancelled. No charge occurred.';
    } else {
      _phase = EntitlementPhase.checkoutReview;
      _message = 'Review this server-owned Demo session. No card, billing account, or real purchase is involved.';
    }
  }

  Future<bool> _refreshAuthority() async {
    try {
      final plans = await _repository.loadPlans();
      final entitlement = await _repository.loadEntitlement();
      _plans = plans.value;
      _entitlement = entitlement.value;
      _isFresh = !plans.isStale && !entitlement.isStale;
      if (!_isFresh) {
        _phase = EntitlementPhase.stale;
        _message = 'Showing cached Demo membership. Capability gates remain closed until fresh authority returns.';
      }
      return _isFresh;
    } on Object catch (error) {
      _isFresh = false;
      _mapReadFailure(error);
      return false;
    }
  }

  Future<void> _restoreProtectedCommand() async {
    if (_protectedCommand != null) return;
    for (final operation in _MembershipOperation.values) {
      final restored = await _journal.restore(_operationName(operation));
      if (restored == null) continue;
      if (!_restoreSnapshot(operation, restored)) {
        await _journal.clear(_operationName(operation));
        continue;
      }
      _protectedCommand = restored;
      _protectedOperation = operation;
      _phase = EntitlementPhase.restoredReview;
      _message =
          'A saved Demo command needs review. Nothing submitted automatically.';
      switch (operation) {
        case _MembershipOperation.create:
          return;
        case _MembershipOperation.confirm:
          await _reconcileConfirm();
          return;
        case _MembershipOperation.restore:
          await _reconcileRestore();
          return;
        case _MembershipOperation.downgrade:
          final baseline = _baselineEntitlement();
          if (baseline == null) {
            await _clearProtected();
            _terminalMessage('The protected entitlement snapshot is invalid.');
          } else {
            await _reconcileDowngrade(baseline);
          }
          return;
      }
    }
  }

  bool _restoreSnapshot(
    _MembershipOperation operation,
    JournaledFinancialCommand command,
  ) {
    final data = command.precondition;
    switch (operation) {
      case _MembershipOperation.create:
        final capability = data['capability'];
        final location = data['return_location'];
        final parsed = capability is String
            ? DemoCapability.fromCode(capability)
            : null;
        if (parsed == null ||
            location is! String ||
            !_validReturnContext(parsed, location) ||
            data['plan_code'] != DemoPlanCode.premiumDemo.wireValue) {
          return false;
        }
        _returnContext = MembershipReturnContext(
          capability: parsed,
          location: location,
        );
        return true;
      case _MembershipOperation.confirm:
        final sessionId = data['session_id'];
        final version = data['version'];
        if (sessionId is! String ||
            !_isUuid(sessionId) ||
            version is! int ||
            version <= 0) {
          return false;
        }
        final capability = data['capability'];
        final location = data['return_location'];
        if (capability is String && location is String) {
          final parsed = DemoCapability.fromCode(capability);
          if (parsed == null || !_validReturnContext(parsed, location)) {
            return false;
          }
          _returnContext = MembershipReturnContext(
            capability: parsed,
            location: location,
          );
        }
        _checkout = DemoCheckout(
          id: sessionId,
          planCode: DemoPlanCode.premiumDemo,
          status: DemoCheckoutStatus.open,
          expiresAt: _now().toUtc().add(const Duration(minutes: 1)),
          version: version,
          disclosure: _plans
              .firstWhere((plan) => plan.code == DemoPlanCode.premiumDemo)
              .disclosure,
        );
        return true;
      case _MembershipOperation.restore:
        return data.isEmpty;
      case _MembershipOperation.downgrade:
        return data['entitlement_id'] is String &&
            _isUuid(data['entitlement_id']! as String) &&
            data['version'] is int &&
            (data['version']! as int) > 0;
    }
  }

  DemoEntitlement? _baselineEntitlement() {
    final command = _protectedCommand;
    final id = command?.precondition['entitlement_id'];
    final version = command?.precondition['version'];
    if (id is! String || version is! int) return null;
    final disclosure = _plans.firstOrNull?.disclosure;
    if (disclosure == null) return null;
    return DemoEntitlement(
      id: id,
      planCode: DemoPlanCode.premiumDemo,
      status: DemoEntitlementStatus.active,
      startsAt: _now().toUtc(),
      version: version,
      disclosure: disclosure,
    );
  }

  Future<void> _mapCommandFailure(Object error) async {
    if (error is LoadFailure) {
      if (error.phase == LoadPhase.forbidden) {
        await _clearProtected();
        _phase = EntitlementPhase.forbidden;
      } else if (error.phase == LoadPhase.throttled) {
        _phase = EntitlementPhase.throttled;
      } else if (error.phase == LoadPhase.retryableFailure) {
        _phase = EntitlementPhase.retryableFailure;
      } else if (error.phase == LoadPhase.conflict) {
        _phase = EntitlementPhase.conflictReview;
      } else {
        await _clearProtected();
        _phase = EntitlementPhase.terminalFailure;
      }
      _message = error.message ?? _commandFailureMessage(_phase);
      return;
    }
    await _clearProtected();
    _terminalMessage('The Demo membership command could not be completed.');
  }

  void _mapReadFailure(Object error) {
    if (error is LoadFailure) {
      _phase = switch (error.phase) {
        LoadPhase.forbidden => EntitlementPhase.forbidden,
        LoadPhase.throttled => EntitlementPhase.throttled,
        LoadPhase.retryableFailure => EntitlementPhase.retryableFailure,
        _ => EntitlementPhase.terminalFailure,
      };
      _message = error.message ?? 'Demo membership authority is unavailable.';
      return;
    }
    if (error is OfflineException) {
      _phase = EntitlementPhase.retryableFailure;
      _message = 'Demo membership is offline. Capability gates remain closed.';
      return;
    }
    _terminalMessage('Demo membership authority could not be validated.');
  }

  Future<void> _afterTransition() async {
    try {
      await _onAuthorityTransition?.call();
    } on Object {
      _message =
          'Membership changed, but the session envelope still needs refresh.';
    }
  }

  Future<void> _clearProtected() async {
    final operation = _protectedOperation;
    if (operation != null) await _journal.clear(_operationName(operation));
    _protectedCommand = null;
    _protectedOperation = null;
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_mutating) return;
    _mutating = true;
    try {
      await action();
    } finally {
      _mutating = false;
    }
  }

  void _terminalMessage(String value) {
    _phase = EntitlementPhase.terminalFailure;
    _message = value;
  }
}

String _operationName(_MembershipOperation operation) => switch (operation) {
  _MembershipOperation.create => 'demo-membership.checkout.create',
  _MembershipOperation.confirm => 'demo-membership.checkout.confirm',
  _MembershipOperation.restore => 'demo-membership.entitlement.restore',
  _MembershipOperation.downgrade => 'demo-membership.entitlement.downgrade',
};

bool _validReturnContext(DemoCapability capability, String location) {
  if (!location.startsWith('/') ||
      location.startsWith('//') ||
      location.contains('://') ||
      location.contains('/admin')) {
    return false;
  }
  return switch (capability) {
    DemoCapability.futureMirror => RegExp(
      r'^/you/portfolios/[A-Za-z0-9][A-Za-z0-9._-]{0,127}/intentions/'
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}/future-mirror'
      r'(?:/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})?$',
    ).hasMatch(location),
    DemoCapability.dailyRitual => location == '/ritual',
    DemoCapability.demoPortfolio => RegExp(
      r'^/you/portfolios/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
    ).hasMatch(location),
  };
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

String _commandFailureMessage(EntitlementPhase phase) => switch (phase) {
  EntitlementPhase.forbidden => 'Demo membership change is not permitted.',
  EntitlementPhase.throttled => 'Demo membership is rate limited. Review the saved command before retrying.',
  EntitlementPhase.retryableFailure => 'Demo membership is temporarily unavailable. Review the saved command before retrying.',
  EntitlementPhase.conflictReview =>
    'Membership authority changed. Refresh and review again.',
  _ => 'The Demo membership command was rejected.',
};
