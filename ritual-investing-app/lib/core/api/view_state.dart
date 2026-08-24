import 'package:flutter/foundation.dart';

enum LoadPhase {
  idle,
  loading,
  ready,
  stale,
  empty,
  forbidden,
  throttled,
  conflict,
  retryableFailure,
}

@immutable
class ViewState<T> {
  const ViewState({required this.phase, this.value, this.committedAt});

  final LoadPhase phase;
  final T? value;
  final DateTime? committedAt;
}

class LoadFailure implements Exception {
  const LoadFailure(this.phase);

  final LoadPhase phase;
}
