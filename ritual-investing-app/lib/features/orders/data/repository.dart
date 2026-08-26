// ignore_for_file: prefer_initializing_formals

import '../domain/model.dart';

abstract interface class OrderService {
  Future<OrderPreview> preview(OrderDraft draft);
  Future<OrderReceipt> commit(OrderCommit command);
  Future<List<OrderView>> list(String portfolioId);
  Future<OrderView> get(String orderId);
}

class OrderRepository {
  const OrderRepository({required OrderService service}) : _service = service;
  final OrderService _service;
  Future<OrderPreview> preview(OrderDraft draft) => _service.preview(draft);
  Future<OrderReceipt> commit(OrderCommit command) => _service.commit(command);
  Future<List<OrderView>> list(String portfolioId) => _service.list(portfolioId);
  Future<OrderView> get(String orderId) => _service.get(orderId);
}
