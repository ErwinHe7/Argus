import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../domain/model.dart';
import 'repository.dart';

/// Strict adapter around the currently generic U5 connection envelope.
///
/// Every field is allowlisted and unknown lifecycle values fail closed. The
/// provider response never reaches presentation code as an untyped object.
class GeneratedBrokerageConnectionApiService
    implements BrokerageConnectionService {
  GeneratedBrokerageConnectionApiService(RitualInvestingApiClient client)
    : _connections = client.getBrokerageConnectionsApi(),
      _reads = client.getBrokerageReadsApi();

  final BrokerageConnectionsApi _connections;
  final BrokerageReadsApi _reads;

  @override
  Future<BrokerageConnectionSnapshot> fetch() async {
    try {
      final responses = await Future.wait<Object>([
        _connections.getWebullConnection(),
        _reads.listWebullAccounts(),
      ]);
      final connection =
          (responses[0] as Response<GetAccount200Response>).data!.data;
      final accounts =
          (responses[1] as Response<BrokerageAccountsResponse>).data!.data;
      return mapBrokerageConnectionSnapshot(connection, accounts);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<BrokerageAuthorizationSession> start() => _authorization(
    () => _connections.startWebullConnection(
      reconnectWebullConnectionRequest: ReconnectWebullConnectionRequest(
        returnTarget:
            ReconnectWebullConnectionRequestReturnTargetEnum.webullNative,
      ),
    ),
  );

  @override
  Future<BrokerageAuthorizationSession> reconnect() => _authorization(
    () => _connections.reconnectWebullConnection(
      reconnectWebullConnectionRequest: ReconnectWebullConnectionRequest(
        returnTarget:
            ReconnectWebullConnectionRequestReturnTargetEnum.webullNative,
      ),
    ),
  );

  Future<BrokerageAuthorizationSession> _authorization(
    Future<Response<GetAccount200Response>> Function() request,
  ) async {
    try {
      final data = _object(await request().then((value) => value.data!.data));
      final authorizationUri = Uri.tryParse(_string(data, 'authorization_url'));
      final expiresAt = DateTime.tryParse(_string(data, 'expires_at'))?.toUtc();
      if (authorizationUri == null ||
          !authorizationUri.isScheme('https') ||
          !authorizationUri.hasAuthority ||
          expiresAt == null) {
        ApiFailureMapper.terminalContract();
      }
      return BrokerageAuthorizationSession(
        authorizationUri: authorizationUri,
        expiresAt: expiresAt,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> selectAccount(String accountId) async {
    try {
      await _connections.selectWebullAccount(
        selectWebullAccountRequest: SelectWebullAccountRequest(
          accountId: accountId,
        ),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> redeemCompletion(String completion) async {
    try {
      await _connections.redeemWebullCompletion(
        redeemWebullCompletionRequest: RedeemWebullCompletionRequest(
          completion: completion,
        ),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }
}

BrokerageConnectionSnapshot mapBrokerageConnectionSnapshot(
  Object? rawConnection,
  List<BrokerageAccount> rawAccounts,
) {
  final connection = rawConnection == null
      ? const <String, Object?>{'status': 'disconnected'}
      : _object(rawConnection);
  final accounts = rawAccounts.map(mapBrokerageAccount).toList(growable: false);
  final active = accounts.where((account) => account.selected).toList();
  if (active.length > 1) ApiFailureMapper.terminalContract();
  final observations = accounts
      .map((account) => account.observedAt)
      .whereType<DateTime>()
      .toList();
  observations.sort();
  return BrokerageConnectionSnapshot(
    phase: _connectionPhase(_string(connection, 'status')),
    accounts: List.unmodifiable(accounts),
    connectionId: _optionalString(connection, 'id'),
    activeAccountId: active.firstOrNull?.id,
    lastAuthoritativeObservation: observations.lastOrNull,
    errorCode: _optionalString(connection, 'last_error_code'),
  );
}

BrokerageAccountView mapBrokerageAccount(BrokerageAccount value) =>
    BrokerageAccountView(
      id: value.id,
      connectionId: value.connectionId,
      displayLabel: value.displayLabel,
      baseCurrency: value.baseCurrency,
      availability: switch (value.status) {
        BrokerageAccountStatusEnum.available =>
          BrokerageAccountAvailability.available,
        BrokerageAccountStatusEnum.restricted =>
          BrokerageAccountAvailability.restricted,
        BrokerageAccountStatusEnum.closed =>
          BrokerageAccountAvailability.closed,
        BrokerageAccountStatusEnum.unavailable =>
          BrokerageAccountAvailability.unavailable,
        BrokerageAccountStatusEnum.unknownDefaultOpenApi =>
          BrokerageAccountAvailability.unknown,
      },
      resourceState: mapBrokerageResourceState(value.state.value),
      capabilityVersion: value.capabilityVersion,
      capabilities: List.unmodifiable(
        value.capabilities.map(
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
        ),
      ),
      selected: value.selected,
      marketTimezone: value.marketTimezone,
      observedAt: value.providerObservedAt?.toUtc() ?? value.fetchedAt?.toUtc(),
      expiresAt: value.expiresAt?.toUtc(),
    );

BrokerageResourceState mapBrokerageResourceState(String value) =>
    switch (value) {
      'fresh' => BrokerageResourceState.fresh,
      'empty' => BrokerageResourceState.empty,
      'stale' => BrokerageResourceState.stale,
      'partial' => BrokerageResourceState.partial,
      'unavailable' => BrokerageResourceState.unavailable,
      'offline' => BrokerageResourceState.offline,
      'rate_limited' => BrokerageResourceState.rateLimited,
      'disconnected' => BrokerageResourceState.disconnected,
      'reauthorization_required' =>
        BrokerageResourceState.reauthorizationRequired,
      _ => BrokerageResourceState.unknown,
    };

BrokerageConnectionPhase _connectionPhase(String value) => switch (value) {
  'disconnected' => BrokerageConnectionPhase.disconnected,
  'pending' => BrokerageConnectionPhase.pending,
  'connected' => BrokerageConnectionPhase.connected,
  'denied' => BrokerageConnectionPhase.denied,
  'failed' => BrokerageConnectionPhase.failed,
  'temporarily_unavailable' => BrokerageConnectionPhase.temporarilyUnavailable,
  'reauthorization_required' =>
    BrokerageConnectionPhase.reauthorizationRequired,
  _ => BrokerageConnectionPhase.unknown,
};

Map<String, Object?> _object(Object? value) {
  if (value is! Map) ApiFailureMapper.terminalContract();
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) ApiFailureMapper.terminalContract();
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _string(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    ApiFailureMapper.terminalContract();
  }
  return field;
}

String? _optionalString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field == null) return null;
  if (field is! String || field.trim().isEmpty) {
    ApiFailureMapper.terminalContract();
  }
  return field;
}
