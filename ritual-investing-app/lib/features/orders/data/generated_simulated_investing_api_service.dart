import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../rebalancing/data/repository.dart';
import '../../rebalancing/domain/model.dart' as rebalance_domain;
import '../../recurring/data/repository.dart';
import '../../recurring/domain/model.dart' as recurring_domain;
import '../domain/model.dart' as order_domain;
import 'repository.dart';

class GeneratedOrderApiService implements OrderService {
  GeneratedOrderApiService(RitualInvestingApiClient client)
    : _mapping = _GeneratedSimulatedInvestingMappings(client);
  final _GeneratedSimulatedInvestingMappings _mapping;
  @override
  Future<order_domain.OrderPreview> preview(order_domain.OrderDraft draft) =>
      _mapping.previewOrder(draft);
  @override
  Future<order_domain.OrderReceipt> commit(order_domain.OrderCommit command) =>
      _mapping.commitOrder(command);
  @override
  Future<List<order_domain.OrderView>> list(String portfolioId) =>
      _mapping.listOrders(portfolioId);
  @override
  Future<order_domain.OrderView> get(String orderId) =>
      _mapping.getOrder(orderId);
}

class GeneratedRecurringPlanApiService implements RecurringPlanService {
  GeneratedRecurringPlanApiService(RitualInvestingApiClient client)
    : _mapping = _GeneratedSimulatedInvestingMappings(client);
  final _GeneratedSimulatedInvestingMappings _mapping;
  @override
  Future<List<recurring_domain.RecurringPlan>> list(String portfolioId) =>
      _mapping.listRecurringPlans(portfolioId);
  @override
  Future<recurring_domain.RecurringPlan> get(String planId) =>
      _mapping.getRecurringPlan(planId);
  @override
  Future<recurring_domain.RecurringPlan> create(
    recurring_domain.RecurringPlanCreate command,
  ) => _mapping.createRecurringPlan(command);
  @override
  Future<recurring_domain.RecurringPlan> edit(
    recurring_domain.RecurringPlanEdit command,
  ) => _mapping.editRecurringPlan(command);
  @override
  Future<recurring_domain.RecurringPlan> pause(String planId, int version) =>
      _mapping.pauseRecurringPlan(planId, version);
  @override
  Future<recurring_domain.RecurringPlan> resume(String planId, int version) =>
      _mapping.resumeRecurringPlan(planId, version);
  @override
  Future<void> cancel(String planId, int version) =>
      _mapping.cancelRecurringPlan(planId, version);
}

class GeneratedRebalanceApiService implements RebalanceService {
  GeneratedRebalanceApiService(RitualInvestingApiClient client)
    : _mapping = _GeneratedSimulatedInvestingMappings(client);
  final _GeneratedSimulatedInvestingMappings _mapping;
  @override
  Future<rebalance_domain.RebalancePreview> preview(
    String portfolioId,
    List<rebalance_domain.RebalanceAllocation> allocations,
  ) => _mapping.previewRebalance(portfolioId, allocations);
  @override
  Future<rebalance_domain.RebalanceReceipt> commit(
    rebalance_domain.RebalanceCommit command,
  ) => _mapping.commitRebalance(command);
}

class _GeneratedSimulatedInvestingMappings {
  _GeneratedSimulatedInvestingMappings(RitualInvestingApiClient client)
    : _orders = OrdersApi(client.dio),
      _recurring = RecurringPlansApi(client.dio),
      _rebalancing = RebalancingApi(client.dio);

  final OrdersApi _orders;
  final RecurringPlansApi _recurring;
  final RebalancingApi _rebalancing;

  Future<order_domain.OrderPreview> previewOrder(
    order_domain.OrderDraft draft,
  ) async {
    try {
      final value = (await _orders.createOrderPreview(
        portfolioId: draft.portfolioId,
        createOrderPreviewRequest: CreateOrderPreviewRequest(
          assetId: draft.assetId,
          side: switch (draft.side) {
            order_domain.OrderSide.buy => CreateOrderPreviewRequestSideEnum.buy,
            order_domain.OrderSide.sell =>
              CreateOrderPreviewRequestSideEnum.sell,
          },
          notional: draft.notionalMinor == null
              ? null
              : PositiveInputMoney(
                  currency: PositiveInputMoneyCurrencyEnum.USD,
                  minorUnits: draft.notionalMinor!,
                ),
          quantity: draft.quantityValue == null
              ? null
              : Quantity(
                  value: draft.quantityValue!,
                  scale: draft.quantityScale!,
                ),
        ),
      )).data!.data;
      return _orderPreview(
        value,
        expectedPortfolioId: draft.portfolioId,
        expectedAssetId: draft.assetId,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<order_domain.OrderReceipt> commitOrder(
    order_domain.OrderCommit command,
  ) async {
    try {
      final value = (await _orders.commitOrder(
        portfolioId: command.portfolioId,
        idempotencyKey: command.idempotencyKey,
        commitOrderRequest: CommitOrderRequest(
          previewId: command.previewId,
          portfolioVersion: command.portfolioVersion,
        ),
      )).data!.data;
      if (value.status != SimulationResultStatusEnum.committed) {
        ApiFailureMapper.terminalContract();
      }
      _requireReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: value.ledgerTransactionIds,
      );
      return order_domain.OrderReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: List.unmodifiable(value.ledgerTransactionIds),
        demo: _orderDemo(value.demo),
      );
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const order_domain.AmbiguousOrderFailure();
      }
      final code = ApiFailureMapper.errorCode(error.response?.data);
      if (code == 'preview_stale' || code == 'version_conflict') {
        throw const order_domain.OrderCommitFailure.stalePreview();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<List<order_domain.OrderView>> listOrders(String portfolioId) async {
    try {
      final values = (await _orders.listOrders(portfolioId: portfolioId))
          .data!
          .data;
      return values
          .map((value) => _orderView(value, expectedPortfolioId: portfolioId))
          .toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<order_domain.OrderView> getOrder(String orderId) async {
    try {
      final value = (await _orders.getOrder(orderId: orderId)).data!.data;
      if (value.id != orderId) ApiFailureMapper.terminalContract();
      return _orderView(value);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<List<recurring_domain.RecurringPlan>> listRecurringPlans(
    String portfolioId,
  ) async {
    try {
      final values = (await _recurring.listRecurringPlans(
        portfolioId: portfolioId,
      )).data!.data;
      return values
          .map(
            (value) => _recurringPlan(value, expectedPortfolioId: portfolioId),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<recurring_domain.RecurringPlan> getRecurringPlan(String planId) async {
    try {
      final value = (await _recurring.getRecurringPlan(planId: planId))
          .data!
          .data;
      if (value.id != planId) ApiFailureMapper.terminalContract();
      return _recurringPlan(value);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<recurring_domain.RecurringPlan> createRecurringPlan(
    recurring_domain.RecurringPlanCreate command,
  ) async {
    final draft = command.draft;
    try {
      final value = (await _recurring.createRecurringPlan(
        portfolioId: draft.portfolioId,
        idempotencyKey: command.idempotencyKey,
        createRecurringPlanRequest: CreateRecurringPlanRequest(
          type: switch (draft.type) {
            recurring_domain.RecurringType.contribution =>
              CreateRecurringPlanRequestTypeEnum.contribution,
            recurring_domain.RecurringType.allocation =>
              CreateRecurringPlanRequestTypeEnum.allocation,
          },
          amount: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: draft.amountMinor,
          ),
          frequency: switch (draft.frequency) {
            recurring_domain.RecurringFrequency.weekly =>
              CreateRecurringPlanRequestFrequencyEnum.weekly,
            recurring_domain.RecurringFrequency.monthly =>
              CreateRecurringPlanRequestFrequencyEnum.monthly,
          },
          sourceId: draft.sourceId,
          allocations: draft.allocations
              .map(
                (item) => CreateRecurringPlanRequestAllocationsInner(
                  assetId: item.assetId,
                  weightBps: item.weightBps,
                ),
              )
              .toList(growable: false),
          firstRunAt: draft.firstRunAt.toUtc(),
        ),
      )).data!.data;
      return _recurringPlan(value, expectedPortfolioId: draft.portfolioId);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const recurring_domain.AmbiguousRecurringCreateFailure();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<recurring_domain.RecurringPlan> editRecurringPlan(
    recurring_domain.RecurringPlanEdit command,
  ) async {
    try {
      final value = (await _recurring.patchRecurringPlan(
        planId: command.planId,
        ifMatch: '"v${command.expectedVersion}"',
        patchRecurringPlanRequest: PatchRecurringPlanRequest(
          amount: command.amountMinor == null
              ? null
              : PositiveInputMoney(
                  currency: PositiveInputMoneyCurrencyEnum.USD,
                  minorUnits: command.amountMinor!,
                ),
          frequency: switch (command.frequency) {
            recurring_domain.RecurringFrequency.weekly =>
              PatchRecurringPlanRequestFrequencyEnum.weekly,
            recurring_domain.RecurringFrequency.monthly =>
              PatchRecurringPlanRequestFrequencyEnum.monthly,
            null => null,
          },
          allocations: command.allocations
              ?.map(
                (item) => CreateRecurringPlanRequestAllocationsInner(
                  assetId: item.assetId,
                  weightBps: item.weightBps,
                ),
              )
              .toList(growable: false),
        ),
      )).data!.data;
      if (value.id != command.planId) ApiFailureMapper.terminalContract();
      return _recurringPlan(value);
    } on DioException catch (error) {
      _throwRecurringMutation(error);
    }
  }

  Future<recurring_domain.RecurringPlan> pauseRecurringPlan(
    String planId,
    int expectedVersion,
  ) => _transitionRecurring(
    planId,
    () => _recurring.pauseRecurringPlan(
      planId: planId,
      ifMatch: '"v$expectedVersion"',
    ),
  );

  Future<recurring_domain.RecurringPlan> resumeRecurringPlan(
    String planId,
    int expectedVersion,
  ) => _transitionRecurring(
    planId,
    () => _recurring.resumeRecurringPlan(
      planId: planId,
      ifMatch: '"v$expectedVersion"',
    ),
  );

  Future<recurring_domain.RecurringPlan> _transitionRecurring(
    String planId,
    Future<Response<CreateRecurringPlan201Response>> Function() request,
  ) async {
    try {
      final value = (await request()).data!.data;
      if (value.id != planId) ApiFailureMapper.terminalContract();
      return _recurringPlan(value);
    } on DioException catch (error) {
      _throwRecurringMutation(error);
    }
  }

  Future<void> cancelRecurringPlan(String planId, int expectedVersion) async {
    try {
      await _recurring.cancelRecurringPlan(
        planId: planId,
        ifMatch: '"v$expectedVersion"',
      );
    } on DioException catch (error) {
      _throwRecurringMutation(error);
    }
  }

  Future<rebalance_domain.RebalancePreview> previewRebalance(
    String portfolioId,
    List<rebalance_domain.RebalanceAllocation> allocations,
  ) async {
    try {
      final value = (await _rebalancing.createRebalancePreview(
        portfolioId: portfolioId,
        createRebalancePreviewRequest: CreateRebalancePreviewRequest(
          targetAllocation: allocations
              .map(
                (item) => CreatePortfolioRequestTargetAllocationInner(
                  assetId: item.assetId,
                  targetBps: item.targetBps,
                ),
              )
              .toList(growable: false),
        ),
      )).data!.data;
      final preview = _rebalancePreview(value);
      if (preview.portfolioId != portfolioId) {
        ApiFailureMapper.terminalContract();
      }
      return preview;
    } on DioException catch (error) {
      if (ApiFailureMapper.errorCode(error.response?.data) ==
          'already_balanced') {
        throw const rebalance_domain.RebalanceAlreadyBalanced();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<rebalance_domain.RebalanceReceipt> commitRebalance(
    rebalance_domain.RebalanceCommit command,
  ) async {
    try {
      final value = (await _rebalancing.commitRebalance(
        portfolioId: command.portfolioId,
        idempotencyKey: command.idempotencyKey,
        commitOrderRequest: CommitOrderRequest(
          previewId: command.previewId,
          portfolioVersion: command.portfolioVersion,
        ),
      )).data!.data;
      if (value.status != SimulationResultStatusEnum.committed) {
        ApiFailureMapper.terminalContract();
      }
      _requireReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: value.ledgerTransactionIds,
      );
      return rebalance_domain.RebalanceReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: List.unmodifiable(value.ledgerTransactionIds),
        demo: _rebalanceDemo(value.demo),
      );
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const rebalance_domain.AmbiguousRebalanceFailure();
      }
      final code = ApiFailureMapper.errorCode(error.response?.data);
      if (code == 'preview_stale' || code == 'version_conflict') {
        throw const rebalance_domain.RebalanceCommitFailure.stalePreview();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  Never _throwRecurringMutation(DioException error) {
    if (ApiFailureMapper.isTransportFailure(error)) {
      throw const recurring_domain.AmbiguousRecurringMutationFailure();
    }
    final code = ApiFailureMapper.errorCode(error.response?.data);
    if (code == 'version_conflict') {
      throw const recurring_domain.RecurringFailure.conflict();
    }
    if (code == 'invalid_transition') {
      throw const recurring_domain.RecurringFailure.invalidTransition();
    }
    ApiFailureMapper.throwFailure(error);
  }

  order_domain.OrderPreview _orderPreview(
    OrderPreview value, {
    required String expectedPortfolioId,
    required String expectedAssetId,
  }) {
    _requireUsd(value.notional.currency);
    _requireUsd(value.frozenPrice.currency);
    if (value.id.trim().isEmpty ||
        value.portfolioId != expectedPortfolioId ||
        value.assetId != expectedAssetId ||
        value.symbol.trim().isEmpty ||
        value.portfolioVersion < 1 ||
        value.notional.minorUnits < 1 ||
        value.frozenPrice.minorUnits < 1 ||
        value.quoteSnapshotId.trim().isEmpty ||
        !_validQuantity(value.quantity.value, value.quantity.scale) ||
        !value.expiresAt.isAfter(value.observedAt)) {
      ApiFailureMapper.terminalContract();
    }
    return order_domain.OrderPreview(
      id: value.id,
      portfolioId: value.portfolioId,
      portfolioVersion: value.portfolioVersion,
      assetId: value.assetId,
      symbol: value.symbol,
      side: switch (value.side) {
        OrderPreviewSideEnum.buy => order_domain.OrderSide.buy,
        OrderPreviewSideEnum.sell => order_domain.OrderSide.sell,
        OrderPreviewSideEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      notionalMinor: value.notional.minorUnits,
      quantityValue: value.quantity.value,
      quantityScale: value.quantity.scale,
      frozenPriceMinor: value.frozenPrice.minorUnits,
      quoteSnapshotId: value.quoteSnapshotId,
      observedAt: value.observedAt.toUtc(),
      expiresAt: value.expiresAt.toUtc(),
      status: switch (value.status) {
        OrderPreviewStatusEnum.active => order_domain.OrderPreviewStatus.active,
        OrderPreviewStatusEnum.executed =>
          order_domain.OrderPreviewStatus.executed,
        OrderPreviewStatusEnum.expired =>
          order_domain.OrderPreviewStatus.expired,
        OrderPreviewStatusEnum.invalidated =>
          order_domain.OrderPreviewStatus.invalidated,
        OrderPreviewStatusEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      demo: _orderDemo(value.demo),
    );
  }

  order_domain.OrderView _orderView(
    SimulatedOrder value, {
    String? expectedPortfolioId,
  }) {
    if (value.notional case final amount?) _requireUsd(amount.currency);
    if (value.fill case final fill?) _requireUsd(fill.price.currency);
    final fill = value.fill;
    if (value.id.trim().isEmpty ||
        value.portfolioId.trim().isEmpty ||
        (expectedPortfolioId != null &&
            value.portfolioId != expectedPortfolioId) ||
        value.commandId.trim().isEmpty ||
        value.assetId.trim().isEmpty ||
        value.symbol.trim().isEmpty ||
        (value.notional != null && value.notional!.minorUnits < 1) ||
        (value.quantity != null &&
            !_validQuantity(value.quantity!.value, value.quantity!.scale)) ||
        (value.notional == null && value.quantity == null) ||
        (value.status == SimulatedOrderStatusEnum.accepted && fill == null) ||
        (value.status == SimulatedOrderStatusEnum.rejected && fill != null) ||
        (fill != null &&
            (!_validQuantity(fill.quantity.value, fill.quantity.scale) ||
                fill.price.minorUnits < 1))) {
      ApiFailureMapper.terminalContract();
    }
    return order_domain.OrderView(
      id: value.id,
      portfolioId: value.portfolioId,
      commandId: value.commandId,
      assetId: value.assetId,
      symbol: value.symbol,
      side: switch (value.side) {
        SimulatedOrderSideEnum.buy => order_domain.OrderSide.buy,
        SimulatedOrderSideEnum.sell => order_domain.OrderSide.sell,
        SimulatedOrderSideEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      status: switch (value.status) {
        SimulatedOrderStatusEnum.accepted => order_domain.OrderStatus.accepted,
        SimulatedOrderStatusEnum.rejected => order_domain.OrderStatus.rejected,
        SimulatedOrderStatusEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      notionalMinor: value.notional?.minorUnits,
      quantityValue: value.quantity?.value,
      quantityScale: value.quantity?.scale,
      fill: value.fill == null
          ? null
          : order_domain.OrderFill(
              quantityValue: value.fill!.quantity.value,
              quantityScale: value.fill!.quantity.scale,
              priceMinor: value.fill!.price.minorUnits,
              filledAt: value.fill!.filledAt.toUtc(),
            ),
      demo: _orderDemo(value.demo),
    );
  }

  recurring_domain.RecurringPlan _recurringPlan(
    RecurringPlan value, {
    String? expectedPortfolioId,
  }) {
    _requireUsd(value.amount.currency);
    final allocations = value.allocations
        .map(
          (item) => recurring_domain.RecurringAllocation(
            assetId: item.assetId,
            weightBps: item.weightBps,
          ),
        )
        .toList(growable: false);
    final runIds = value.recentRuns
        .map((run) => run.id)
        .toList(growable: false);
    if (value.id.trim().isEmpty ||
        value.portfolioId.trim().isEmpty ||
        (expectedPortfolioId != null &&
            value.portfolioId != expectedPortfolioId) ||
        value.amount.minorUnits < 1 ||
        value.version < 1 ||
        !_validRecurringAllocations(allocations) ||
        runIds.any((id) => id.trim().isEmpty) ||
        runIds.toSet().length != runIds.length) {
      ApiFailureMapper.terminalContract();
    }
    return recurring_domain.RecurringPlan(
      id: value.id,
      portfolioId: value.portfolioId,
      type: switch (value.type) {
        RecurringPlanTypeEnum.contribution =>
          recurring_domain.RecurringType.contribution,
        RecurringPlanTypeEnum.allocation =>
          recurring_domain.RecurringType.allocation,
        RecurringPlanTypeEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      amountMinor: value.amount.minorUnits,
      frequency: switch (value.frequency) {
        RecurringPlanFrequencyEnum.weekly =>
          recurring_domain.RecurringFrequency.weekly,
        RecurringPlanFrequencyEnum.monthly =>
          recurring_domain.RecurringFrequency.monthly,
        RecurringPlanFrequencyEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      nextRunAt: value.nextRunAt.toUtc(),
      status: switch (value.status) {
        RecurringPlanStatusEnum.active =>
          recurring_domain.RecurringStatus.active,
        RecurringPlanStatusEnum.paused =>
          recurring_domain.RecurringStatus.paused,
        RecurringPlanStatusEnum.cancelled =>
          recurring_domain.RecurringStatus.cancelled,
        RecurringPlanStatusEnum.completed =>
          recurring_domain.RecurringStatus.completed,
        RecurringPlanStatusEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      allocations: allocations,
      recentRuns: value.recentRuns
          .map(
            (item) => recurring_domain.RecurringRun(
              id: item.id,
              scheduledFor: item.scheduledFor.toUtc(),
              status: switch (item.status) {
                RecurringPlanRecentRunsInnerStatusEnum.due =>
                  recurring_domain.RecurringRunStatus.due,
                RecurringPlanRecentRunsInnerStatusEnum.running =>
                  recurring_domain.RecurringRunStatus.running,
                RecurringPlanRecentRunsInnerStatusEnum.completed =>
                  recurring_domain.RecurringRunStatus.completed,
                RecurringPlanRecentRunsInnerStatusEnum.rejected =>
                  recurring_domain.RecurringRunStatus.rejected,
                RecurringPlanRecentRunsInnerStatusEnum.unknownDefaultOpenApi =>
                  ApiFailureMapper.terminalContract(),
              },
            ),
          )
          .toList(growable: false),
      version: value.version,
      demo: _recurringDemo(value.demo),
    );
  }

  rebalance_domain.RebalancePreview _rebalancePreview(RebalancePreview value) {
    final targetAllocation = value.targetAllocation
        .map(
          (item) => rebalance_domain.RebalanceAllocation(
            assetId: item.assetId,
            targetBps: item.targetBps,
          ),
        )
        .toList(growable: false);
    final tradeIds = value.trades.map((trade) => trade.assetId).toList();
    if (value.id.trim().isEmpty ||
        value.portfolioId.trim().isEmpty ||
        value.portfolioVersion < 1 ||
        !rebalance_domain.validRebalanceAllocations(targetAllocation) ||
        value.trades.isEmpty ||
        tradeIds.any((id) => id.trim().isEmpty) ||
        tradeIds.toSet().length != tradeIds.length ||
        value.trades.any(
          (trade) =>
              !_validQuantity(trade.quantity.value, trade.quantity.scale) ||
              trade.notional.minorUnits < 1,
        )) {
      ApiFailureMapper.terminalContract();
    }
    return rebalance_domain.RebalancePreview(
      id: value.id,
      portfolioId: value.portfolioId,
      portfolioVersion: value.portfolioVersion,
      targetAllocation: targetAllocation,
      trades: value.trades
          .map((item) {
            _requireUsd(item.notional.currency);
            return rebalance_domain.RebalanceTrade(
              assetId: item.assetId,
              side: switch (item.side) {
                RebalancePreviewTradesInnerSideEnum.buy =>
                  rebalance_domain.RebalanceSide.buy,
                RebalancePreviewTradesInnerSideEnum.sell =>
                  rebalance_domain.RebalanceSide.sell,
                RebalancePreviewTradesInnerSideEnum.unknownDefaultOpenApi =>
                  ApiFailureMapper.terminalContract(),
              },
              quantityValue: item.quantity.value,
              quantityScale: item.quantity.scale,
              notionalMinor: item.notional.minorUnits,
            );
          })
          .toList(growable: false),
      expiresAt: value.expiresAt.toUtc(),
      status: switch (value.status) {
        RebalancePreviewStatusEnum.active =>
          rebalance_domain.RebalancePreviewStatus.active,
        RebalancePreviewStatusEnum.executed =>
          rebalance_domain.RebalancePreviewStatus.executed,
        RebalancePreviewStatusEnum.expired =>
          rebalance_domain.RebalancePreviewStatus.expired,
        RebalancePreviewStatusEnum.invalidated =>
          rebalance_domain.RebalancePreviewStatus.invalidated,
        RebalancePreviewStatusEnum.unknownDefaultOpenApi =>
          ApiFailureMapper.terminalContract(),
      },
      demo: _rebalanceDemo(value.demo),
    );
  }

  order_domain.OrderDemoDisclosure _orderDemo(SimulationDemoDisclosure value) {
    _requireGeneratedDemo(value);
    return order_domain.OrderDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  recurring_domain.RecurringDemoDisclosure _recurringDemo(
    SimulationDemoDisclosure value,
  ) {
    _requireGeneratedDemo(value);
    return recurring_domain.RecurringDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  rebalance_domain.RebalanceDemoDisclosure _rebalanceDemo(
    SimulationDemoDisclosure value,
  ) {
    _requireGeneratedDemo(value);
    return rebalance_domain.RebalanceDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  void _requireUsd(MoneyCurrencyEnum currency) {
    if (currency != MoneyCurrencyEnum.USD) ApiFailureMapper.terminalContract();
  }

  void _requireGeneratedDemo(SimulationDemoDisclosure value) {
    if (!value.isDemo ||
        value.sourceLabel.trim().isEmpty ||
        value.limitations.isEmpty ||
        value.limitations.any((item) => item.trim().isEmpty)) {
      ApiFailureMapper.terminalContract();
    }
  }

  void _requireReceipt({
    required String commandId,
    required int portfolioVersion,
    required List<String> ledgerTransactionIds,
  }) {
    if (commandId.trim().isEmpty ||
        portfolioVersion < 1 ||
        ledgerTransactionIds.isEmpty ||
        ledgerTransactionIds.any((id) => id.trim().isEmpty) ||
        ledgerTransactionIds.toSet().length != ledgerTransactionIds.length) {
      ApiFailureMapper.terminalContract();
    }
  }

  bool _validRecurringAllocations(
    List<recurring_domain.RecurringAllocation> allocations,
  ) =>
      allocations.isNotEmpty &&
      allocations.length <= 50 &&
      allocations.every(
        (allocation) =>
            allocation.assetId.trim().isNotEmpty &&
            allocation.weightBps >= 0 &&
            allocation.weightBps <= 10000,
      ) &&
      allocations.map((allocation) => allocation.assetId).toSet().length ==
          allocations.length &&
      allocations.fold<int>(0, (sum, value) => sum + value.weightBps) == 10000;

  bool _validQuantity(String value, int scale) =>
      scale >= 0 &&
      scale <= 12 &&
      RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,12})?$').hasMatch(value) &&
      value.replaceAll(RegExp(r'[^0-9]'), '').contains(RegExp(r'[1-9]'));
}
