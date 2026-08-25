// ignore_for_file: prefer_initializing_formals

import '../domain/model.dart';

abstract interface class RebalanceService {
  Future<RebalancePreview> preview(
    String portfolioId,
    List<RebalanceAllocation> allocations,
  );
  Future<RebalanceReceipt> commit(RebalanceCommit command);
}

class RebalanceRepository {
  const RebalanceRepository({required RebalanceService service}) : _service = service;
  final RebalanceService _service;
  Future<RebalancePreview> preview(
    String portfolioId,
    List<RebalanceAllocation> allocations,
  ) => _service.preview(portfolioId, allocations);
  Future<RebalanceReceipt> commit(RebalanceCommit command) => _service.commit(command);
}
