import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../features/brokerage_connection/data/generated_brokerage_connection_api_service.dart';
import '../../features/brokerage_connection/domain/model.dart';
import '../bootstrap/generated_member_bootstrap_mapper.dart';
import '../bootstrap/member_bootstrap.dart';
import 'api_failure_mapper.dart';

export '../../features/coven/data/generated_coven_api_service.dart';
export '../../features/brokerage_connection/data/generated_brokerage_connection_api_service.dart';
export '../../features/discover/data/generated_discover_api_service.dart';
export '../../features/intentions/data/generated_intention_api_service.dart';
export '../../features/orders/data/generated_brokerage_order_api_service.dart';
export '../../features/profile/data/generated_profile_api_service.dart';
export '../../features/ritual/data/generated_ritual_api_service.dart';
export 'api_failure_mapper.dart';

abstract interface class SessionBootstrapService {
  Future<MemberBootstrap> bootstrap();
}

class GeneratedSessionBootstrapService implements SessionBootstrapService {
  GeneratedSessionBootstrapService(RitualInvestingApiClient client)
    : _api = client.getSessionApi(),
      _brokerage = GeneratedBrokerageConnectionApiService(client);

  final SessionApi _api;
  final GeneratedBrokerageConnectionApiService _brokerage;

  @override
  Future<MemberBootstrap> bootstrap() async {
    try {
      final values = await Future.wait<Object>([
        _api.bootstrapSession(),
        _safeBrokerageBootstrap(),
      ]);
      final session =
          (values[0] as Response<SessionBootstrapResponse>).data?.data;
      if (session == null) ApiFailureMapper.terminalContract();
      return mapSupabaseSessionBootstrap(
        session.toJson(),
        values[1] as BrokerageConnectionSnapshot,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  Future<BrokerageConnectionSnapshot> _safeBrokerageBootstrap() async {
    try {
      return await _brokerage.fetch();
    } on Object {
      return const BrokerageConnectionSnapshot(
        phase: BrokerageConnectionPhase.temporarilyUnavailable,
        accounts: [],
      );
    }
  }
}
