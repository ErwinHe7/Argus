// ignore_for_file: prefer_initializing_formals

import '../domain/model.dart';

abstract interface class RecurringPlanService {
  Future<List<RecurringPlan>> list(String portfolioId);
  Future<RecurringPlan> get(String planId);
  Future<RecurringPlan> create(RecurringPlanCreate command);
  Future<RecurringPlan> edit(RecurringPlanEdit command);
  Future<RecurringPlan> pause(String planId, int expectedVersion);
  Future<RecurringPlan> resume(String planId, int expectedVersion);
  Future<void> cancel(String planId, int expectedVersion);
}

class RecurringPlanRepository {
  const RecurringPlanRepository({required RecurringPlanService service})
    : _service = service;
  final RecurringPlanService _service;
  Future<List<RecurringPlan>> list(String portfolioId) => _service.list(portfolioId);
  Future<RecurringPlan> get(String planId) => _service.get(planId);
  Future<RecurringPlan> create(RecurringPlanCreate command) => _service.create(command);
  Future<RecurringPlan> edit(RecurringPlanEdit command) => _service.edit(command);
  Future<RecurringPlan> pause(String planId, int expectedVersion) =>
      _service.pause(planId, expectedVersion);
  Future<RecurringPlan> resume(String planId, int expectedVersion) =>
      _service.resume(planId, expectedVersion);
  Future<void> cancel(String planId, int expectedVersion) =>
      _service.cancel(planId, expectedVersion);
}
