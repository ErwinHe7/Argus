// ignore_for_file: prefer_initializing_formals

import '../domain/model.dart';

abstract interface class BrokerageConnectionService {
  Future<BrokerageConnectionSnapshot> fetch();
  Future<BrokerageAuthorizationSession> start();
  Future<BrokerageAuthorizationSession> reconnect();
  Future<void> selectAccount(String accountId);
  Future<void> redeemCompletion(String completion);
}

class BrokerageConnectionRepository {
  const BrokerageConnectionRepository({
    required BrokerageConnectionService service,
  }) : _service = service;

  final BrokerageConnectionService _service;

  Future<BrokerageConnectionSnapshot> load() => _service.fetch();
  Future<BrokerageAuthorizationSession> start() => _service.start();
  Future<BrokerageAuthorizationSession> reconnect() => _service.reconnect();
  Future<void> selectAccount(String accountId) =>
      _service.selectAccount(accountId);
  Future<void> redeemCompletion(String completion) =>
      _service.redeemCompletion(completion);
}
