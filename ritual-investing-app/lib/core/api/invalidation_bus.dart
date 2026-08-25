import 'dart:async';

import '../cache/read_cache.dart';

class InvalidationEvent {
  const InvalidationEvent({required this.scope, required this.resource});

  final CacheScope scope;
  final String resource;

  @override
  bool operator ==(Object other) =>
      other is InvalidationEvent &&
      other.scope == scope &&
      other.resource == resource;

  @override
  int get hashCode => Object.hash(scope, resource);
}

class InvalidationBus {
  final StreamController<InvalidationEvent> _controller =
      StreamController<InvalidationEvent>.broadcast(sync: true);

  Stream<InvalidationEvent> eventsFor(CacheScope scope) =>
      _controller.stream.where((event) => event.scope == scope);

  void publish(InvalidationEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}
