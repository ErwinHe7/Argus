// ignore_for_file: prefer_initializing_formals

import '../domain/brokerage_model.dart';

abstract interface class BrokeragePortfolioService {
  Future<BrokeragePortfolioSnapshot> fetch(
    String accountId, {
    required bool refresh,
  });
}

class BrokeragePortfolioRepository {
  const BrokeragePortfolioRepository({
    required BrokeragePortfolioService service,
  }) : _service = service;

  final BrokeragePortfolioService _service;

  Future<BrokeragePortfolioSnapshot> load(
    String accountId, {
    bool refresh = false,
  }) => _service.fetch(accountId, refresh: refresh);
}
