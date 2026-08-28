// ignore_for_file: prefer_initializing_formals

import '../domain/brokerage_model.dart';

abstract interface class BrokerageOrderService {
  Future<BrokerageOrderListView> list(String accountId, {bool refresh = false});
  Future<BrokerageOrderDetailView> get(String accountId, String orderId);
  Future<BrokerageOrderPreviewView> previewPlace(
    String accountId,
    BrokeragePlaceOrderIntent intent,
  );
  Future<BrokerageOrderPreviewView> previewModify(
    String accountId,
    String orderId,
    BrokerageModifyOrderIntent intent,
  );
  Future<BrokerageOrderPreviewView> previewCancel(
    String accountId,
    String orderId,
  );
  Future<BrokerageOrderCommandView> confirmPlace({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  });
  Future<BrokerageOrderCommandView> confirmModify({
    required BrokerageOrderPreviewView preview,
    required BrokerageModifyOrderIntent intent,
    required String idempotencyKey,
  });
  Future<BrokerageOrderCommandView> confirmCancel({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  });
  Future<BrokerageOrderCommandView> getCommand(String commandId);
}

class BrokerageOrderRepository {
  const BrokerageOrderRepository({required BrokerageOrderService service})
    : _service = service;

  final BrokerageOrderService _service;

  Future<BrokerageOrderListView> list(
    String accountId, {
    bool refresh = false,
  }) => _service.list(accountId, refresh: refresh);
  Future<BrokerageOrderDetailView> get(String accountId, String orderId) =>
      _service.get(accountId, orderId);
  Future<BrokerageOrderPreviewView> previewPlace(
    String accountId,
    BrokeragePlaceOrderIntent intent,
  ) => _service.previewPlace(accountId, intent);
  Future<BrokerageOrderPreviewView> previewModify(
    String accountId,
    String orderId,
    BrokerageModifyOrderIntent intent,
  ) => _service.previewModify(accountId, orderId, intent);
  Future<BrokerageOrderPreviewView> previewCancel(
    String accountId,
    String orderId,
  ) => _service.previewCancel(accountId, orderId);
  Future<BrokerageOrderCommandView> confirmPlace({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) => _service.confirmPlace(preview: preview, idempotencyKey: idempotencyKey);
  Future<BrokerageOrderCommandView> confirmModify({
    required BrokerageOrderPreviewView preview,
    required BrokerageModifyOrderIntent intent,
    required String idempotencyKey,
  }) => _service.confirmModify(
    preview: preview,
    intent: intent,
    idempotencyKey: idempotencyKey,
  );
  Future<BrokerageOrderCommandView> confirmCancel({
    required BrokerageOrderPreviewView preview,
    required String idempotencyKey,
  }) =>
      _service.confirmCancel(preview: preview, idempotencyKey: idempotencyKey);
  Future<BrokerageOrderCommandView> getCommand(String commandId) =>
      _service.getCommand(commandId);
}
