import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../brokerage_connection/data/generated_brokerage_connection_api_service.dart';
import '../../brokerage_connection/domain/model.dart';
import '../domain/brokerage_model.dart';
import 'brokerage_repository.dart';

class GeneratedBrokeragePortfolioApiService
    implements BrokeragePortfolioService {
  GeneratedBrokeragePortfolioApiService(RitualInvestingApiClient client)
    : _api = client.getBrokerageReadsApi();

  final BrokerageReadsApi _api;

  @override
  Future<BrokeragePortfolioSnapshot> fetch(
    String accountId, {
    required bool refresh,
  }) async {
    try {
      final refreshQuery = refresh ? 'true' : null;
      final values = await Future.wait<Object>([
        _api.getWebullBalances(accountId: accountId, refresh: refreshQuery),
        _api.getWebullPositions(accountId: accountId, refresh: refreshQuery),
        _api.getWebullAccountCapabilities(
          accountId: accountId,
          refresh: refreshQuery,
        ),
        _api.getWebullRestrictions(accountId: accountId, refresh: refreshQuery),
      ]);
      final balance =
          (values[0] as Response<BrokerageBalancesResponse>).data!.data;
      final positions =
          (values[1] as Response<BrokeragePositionsResponse>).data!.data;
      final capabilities =
          (values[2] as Response<BrokerageCapabilitiesResponse>).data!.data;
      final restrictions =
          (values[3] as Response<BrokerageRestrictionsResponse>).data!.data;
      if ({
                balance.accountId,
                positions.accountId,
                capabilities.accountId,
                restrictions.accountId,
              }.length !=
              1 ||
          balance.accountId != accountId) {
        ApiFailureMapper.terminalContract();
      }
      return BrokeragePortfolioSnapshot(
        accountId: accountId,
        balance: BrokerageObservation(
          state: mapBrokerageResourceState(balance.state.value),
          value: balance.data == null
              ? null
              : BrokerageBalanceView(
                  currency: balance.data!.currency,
                  cash: balance.data!.cash,
                  totalEquity: balance.data!.totalEquity,
                  marketValue: balance.data!.marketValue,
                  buyingPower: balance.data!.buyingPower,
                ),
          observedAt:
              balance.providerObservedAt?.toUtc() ?? balance.fetchedAt?.toUtc(),
          expiresAt: balance.expiresAt?.toUtc(),
          reason: balance.reason,
        ),
        positions: BrokerageObservation(
          state: mapBrokerageResourceState(positions.state.value),
          value: positions.data
              ?.map(
                (position) => BrokeragePositionView(
                  instrumentId: position.asset.instrumentId,
                  symbol: position.asset.symbol,
                  name: position.asset.name,
                  quantity: position.quantity,
                  availableQuantity: position.availableQuantity,
                  currency: position.currency,
                  supported:
                      position.asset.supported &&
                      (position.asset.assetKind ==
                              BrokerageAssetAssetKindEnum.equity ||
                          position.asset.assetKind ==
                              BrokerageAssetAssetKindEnum.etf),
                  marketValue: position.marketValue,
                  averageCost: position.averageCost,
                ),
              )
              .toList(growable: false),
          observedAt:
              positions.providerObservedAt?.toUtc() ??
              positions.fetchedAt?.toUtc(),
          expiresAt: positions.expiresAt?.toUtc(),
          reason: positions.reason,
        ),
        capabilities: BrokerageObservation(
          state: mapBrokerageResourceState(capabilities.state.value),
          value: capabilities.data?.capabilities
              .map(
                (capability) => BrokerageCapabilityView(
                  kind: switch (capability.capability) {
                    BrokerageCapabilityCapabilityEnum.balancesRead =>
                      BrokerageCapabilityKind.balancesRead,
                    BrokerageCapabilityCapabilityEnum.positionsRead =>
                      BrokerageCapabilityKind.positionsRead,
                    BrokerageCapabilityCapabilityEnum.ordersRead =>
                      BrokerageCapabilityKind.ordersRead,
                    BrokerageCapabilityCapabilityEnum.manualOrders =>
                      BrokerageCapabilityKind.manualOrders,
                    BrokerageCapabilityCapabilityEnum.unsupported =>
                      BrokerageCapabilityKind.unsupported,
                    BrokerageCapabilityCapabilityEnum.unknownDefaultOpenApi =>
                      BrokerageCapabilityKind.unknown,
                  },
                  available: capability.available,
                  providerCode: capability.providerCode,
                ),
              )
              .toList(growable: false),
          observedAt:
              capabilities.providerObservedAt?.toUtc() ??
              capabilities.fetchedAt?.toUtc(),
          expiresAt: capabilities.expiresAt?.toUtc(),
          reason: capabilities.reason,
        ),
        restrictions: BrokerageObservation(
          state: mapBrokerageResourceState(restrictions.state.value),
          value: restrictions.data
              ?.map(
                (restriction) => BrokerageRestrictionView(
                  code: restriction.restriction.value,
                  active: restriction.active,
                  providerCode: restriction.providerCode,
                  detail: restriction.detail,
                ),
              )
              .toList(growable: false),
          observedAt:
              restrictions.providerObservedAt?.toUtc() ??
              restrictions.fetchedAt?.toUtc(),
          expiresAt: restrictions.expiresAt?.toUtc(),
          reason: restrictions.reason,
        ),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }
}
