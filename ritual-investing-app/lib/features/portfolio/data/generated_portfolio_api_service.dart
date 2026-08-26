import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../funding/data/repository.dart';
import '../../funding/domain/model.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedPortfolioApiService implements PortfolioService, FundingService {
  GeneratedPortfolioApiService(RitualInvestingApiClient client)
    : _portfolios = PortfoliosApi(client.dio),
      _simulation = SimulationApi(client.dio);

  final PortfoliosApi _portfolios;
  final SimulationApi _simulation;

  @override
  Future<PortfolioCollection> fetchList() async {
    try {
      final values = (await _portfolios.listPortfolios()).data!.data;
      return PortfolioCollection(
        items: values.map(_portfolio).toList(growable: false),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<PortfolioSummary> fetchDetail(String portfolioId) async {
    try {
      return _portfolio(
        (await _portfolios.getPortfolio(portfolioId: portfolioId)).data!.data,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<PortfolioHolding>> fetchHoldings(String portfolioId) async {
    try {
      final values = (await _portfolios.listPortfolioHoldings(
        portfolioId: portfolioId,
      )).data!.data;
      return values.map(_holding).toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<PortfolioActivityEntry>> fetchActivity(String portfolioId) async {
    try {
      final values = (await _portfolios.listPortfolioActivity(
        portfolioId: portfolioId,
      )).data!.data;
      return values.map(_activity).toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<PortfolioSnapshotView>> fetchSnapshots(String portfolioId) async {
    try {
      final values = (await _portfolios.listPortfolioSnapshots(
        portfolioId: portfolioId,
      )).data!.data;
      return values.map(_snapshot).toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _portfolios.createPortfolio(
        idempotencyKey: idempotencyKey,
        createPortfolioRequest: CreatePortfolioRequest(
          currency: CreatePortfolioRequestCurrencyEnum.USD,
          name: name,
        ),
      );
      return _portfolio(response.data!.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const PortfolioAmbiguousMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) async {
    try {
      final response = await _portfolios.patchPortfolio(
        portfolioId: portfolioId,
        ifMatch: '"v$expectedVersion"',
        patchPortfolioRequest: PatchPortfolioRequest(name: name),
      );
      return _portfolio(response.data!.data);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) async {
    try {
      await _portfolios.archivePortfolio(
        portfolioId: portfolioId,
        ifMatch: '"v$expectedVersion"',
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<FundingSource>> fetchSources() async {
    try {
      final values = (await _portfolios.listDemoFundingSources()).data!.data;
      return values.map(_fundingSource).toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) async {
    try {
      final result = (await _portfolios.createDemoFundingSource(
        idempotencyKey: idempotencyKey,
        createDemoFundingSourceRequest: CreateDemoFundingSourceRequest(
          fixtureKey: switch (fixture) {
            FundingFixture.moonReserve =>
              CreateDemoFundingSourceRequestFixtureKeyEnum.moonReserve,
            FundingFixture.constellationSavings =>
              CreateDemoFundingSourceRequestFixtureKeyEnum.constellationSavings,
          },
        ),
      )).data!.data;
      return _fundingSource(result);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> deleteSource(String sourceId) async {
    try {
      await _portfolios.deleteDemoFundingSource(sourceId: sourceId);
    } on DioException catch (error) {
      if (ApiFailureMapper.errorCode(error.response?.data) ==
          'funding_source_in_use') {
        throw const FundingFailure.fundingSourceInUse();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) async {
    try {
      if (command.currency != PortfolioCurrency.usd) {
        ApiFailureMapper.terminalContract();
      }
      final result = (await _simulation.createDemoContribution(
        portfolioId: command.portfolioId,
        idempotencyKey: command.idempotencyKey,
        createDemoContributionRequest: CreateDemoContributionRequest(
          amount: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: command.minorUnits,
          ),
          effectiveAt: command.effectiveAt?.toUtc(),
          sourceId: command.sourceId,
        ),
      )).data!.data;
      if (result.status != SimulationResultStatusEnum.committed) {
        ApiFailureMapper.terminalContract();
      }
      return ContributionReceipt(
        commandId: result.commandId,
        portfolioVersion: result.portfolioVersion,
        ledgerTransactionIds: List.unmodifiable(result.ledgerTransactionIds),
        demo: _fundingDemo(result.demo),
      );
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const AmbiguousContributionFailure();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  PortfolioSummary _portfolio(PortfolioView value) {
    _requirePortfolioCurrency(value.currency);
    _requireMoneyCurrency(value.cash.currency);
    _requireMoneyCurrency(value.latestValuation.currency);
    final status = switch (value.status) {
      PortfolioViewStatusEnum.active => PortfolioStatus.active,
      PortfolioViewStatusEnum.archived => PortfolioStatus.archived,
      PortfolioViewStatusEnum.unknownDefaultOpenApi =>
        ApiFailureMapper.terminalContract(),
    };
    final targetAllocation = value.targetAllocation
        .map((target) {
          if (target.targetBps < 0 || target.targetBps > 10000) {
            ApiFailureMapper.terminalContract();
          }
          return PortfolioTargetAllocation(
            assetId: target.assetId,
            targetBps: target.targetBps,
          );
        })
        .toList(growable: false);
    return PortfolioSummary(
      id: value.id,
      name: value.name,
      cashMinor: value.cash.minorUnits,
      valuationMinor: value.latestValuation.minorUnits,
      currency: PortfolioCurrency.usd,
      status: status,
      isDefault: value.isDefault,
      version: value.version,
      ledgerWatermark: value.ledgerWatermark,
      asOfTransactionId: value.asOfTransactionId,
      demo: _portfolioDemo(value.demo),
      targetAllocation: List.unmodifiable(targetAllocation),
    );
  }

  PortfolioHolding _holding(ListPortfolioHoldings200ResponseDataInner value) {
    _requireMoneyCurrency(value.marketValue.currency);
    return PortfolioHolding(
      assetId: value.assetId,
      symbol: value.symbol,
      quantityValue: value.quantity.value,
      quantityScale: value.quantity.scale,
      marketValueMinor: value.marketValue.minorUnits,
      currency: PortfolioCurrency.usd,
      ledgerWatermark: value.ledgerWatermark,
      asOfTransactionId: value.asOfTransactionId,
    );
  }

  PortfolioActivityEntry _activity(PortfolioActivity value) {
    if (value.cash.currency != SignedMoneyCurrencyEnum.USD) {
      ApiFailureMapper.terminalContract();
    }
    final type = switch (value.type) {
      PortfolioActivityTypeEnum.contribution =>
        PortfolioActivityType.contribution,
      PortfolioActivityTypeEnum.order => PortfolioActivityType.order,
      PortfolioActivityTypeEnum.rebalance => PortfolioActivityType.rebalance,
      PortfolioActivityTypeEnum.recurring => PortfolioActivityType.recurring,
      PortfolioActivityTypeEnum.unknownDefaultOpenApi =>
        ApiFailureMapper.terminalContract(),
    };
    return PortfolioActivityEntry(
      id: value.id,
      type: type,
      descriptionCode: value.descriptionCode,
      effectiveAt: value.effectiveAt.toUtc(),
      cashMinor: value.cash.minorUnits,
      currency: PortfolioCurrency.usd,
      ledgerWatermark: value.ledgerWatermark,
      demo: _portfolioDemo(value.demo),
    );
  }

  PortfolioSnapshotView _snapshot(PortfolioSnapshot value) {
    _requireMoneyCurrency(value.cash.currency);
    _requireMoneyCurrency(value.marketValue.currency);
    return PortfolioSnapshotView(
      id: value.id,
      asOfTransactionId: value.asOfTransactionId,
      ledgerWatermark: value.ledgerWatermark,
      asOf: value.asOf.toUtc(),
      cashMinor: value.cash.minorUnits,
      marketValueMinor: value.marketValue.minorUnits,
      currency: PortfolioCurrency.usd,
      demo: _portfolioDemo(value.demo),
    );
  }

  FundingSource _fundingSource(DemoFundingSource value) {
    final fixture = switch (value.fixtureKey) {
      DemoFundingSourceFixtureKeyEnum.moonReserve => FundingFixture.moonReserve,
      DemoFundingSourceFixtureKeyEnum.constellationSavings =>
        FundingFixture.constellationSavings,
      DemoFundingSourceFixtureKeyEnum.unknownDefaultOpenApi =>
        ApiFailureMapper.terminalContract(),
    };
    final expected = switch (fixture) {
      FundingFixture.moonReserve => ('Moon Reserve (fictional)', '1108'),
      FundingFixture.constellationSavings => (
        'Constellation Savings (fictional)',
        '2042',
      ),
    };
    if (value.displayLabel != expected.$1 ||
        value.fictionalLast4 != expected.$2) {
      ApiFailureMapper.terminalContract();
    }
    final status = switch (value.status) {
      DemoFundingSourceStatusEnum.active => FundingSourceStatus.active,
      DemoFundingSourceStatusEnum.inactive => FundingSourceStatus.inactive,
      DemoFundingSourceStatusEnum.unknownDefaultOpenApi =>
        ApiFailureMapper.terminalContract(),
    };
    return FundingSource(
      id: value.id,
      fixture: fixture,
      displayLabel: value.displayLabel,
      fictionalLast4: value.fictionalLast4,
      status: status,
      demo: _fundingDemo(value.demo),
    );
  }

  PortfolioDemoDisclosure _portfolioDemo(SimulationDemoDisclosure value) {
    _requireDemo(value);
    return PortfolioDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  FundingDemoDisclosure _fundingDemo(SimulationDemoDisclosure value) {
    _requireDemo(value);
    return FundingDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  void _requireDemo(SimulationDemoDisclosure value) {
    if (!value.isDemo ||
        value.sourceLabel.trim().isEmpty ||
        value.limitations.isEmpty) {
      ApiFailureMapper.terminalContract();
    }
  }

  void _requirePortfolioCurrency(PortfolioViewCurrencyEnum currency) {
    if (currency != PortfolioViewCurrencyEnum.USD) {
      ApiFailureMapper.terminalContract();
    }
  }

  void _requireMoneyCurrency(MoneyCurrencyEnum currency) {
    if (currency != MoneyCurrencyEnum.USD) ApiFailureMapper.terminalContract();
  }
}
