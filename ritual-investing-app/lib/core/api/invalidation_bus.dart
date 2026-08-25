import 'dart:async';

import '../cache/read_cache.dart';

enum InvalidationResource { ledger, notifications, portfolios }

class InvalidationEvent {
  const InvalidationEvent({
    required this.scope,
    required this.resource,
    this.ledgerWatermark,
  });

  final CacheScope scope;
  final InvalidationResource resource;
  final int? ledgerWatermark;

  @override
  bool operator ==(Object other) =>
      other is InvalidationEvent &&
      other.scope == scope &&
      other.resource == resource &&
      other.ledgerWatermark == ledgerWatermark;

  @override
  int get hashCode => Object.hash(scope, resource, ledgerWatermark);
}

class InvalidationBus {
  final StreamController<InvalidationEvent> _controller =
      StreamController<InvalidationEvent>.broadcast(sync: true);

  Stream<InvalidationEvent> eventsFor(CacheScope scope) =>
      _controller.stream.where((event) => event.scope == scope);

  void publish(InvalidationEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}
