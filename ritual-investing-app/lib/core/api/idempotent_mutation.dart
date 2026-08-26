// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../cache/cached_read.dart';

enum MutationPhase { idle, committing, committed, retryableFailure }

@immutable
class MutationState<T> {
  const MutationState({required this.phase, this.value, this.idempotencyKey});

  final MutationPhase phase;
  final T? value;
  final String? idempotencyKey;
}

abstract interface class MutationService<T> {
  Future<T> execute(String idempotencyKey);
}

class IdempotentMutation<T> extends ChangeNotifier {
  IdempotentMutation({
    required MutationService<T> service,
    required String Function() createKey,
  }) : _service = service,
       _createKey = createKey;

  final MutationService<T> _service;
  final String Function() _createKey;
  MutationState<T> _state = const MutationState(phase: MutationPhase.idle);

  MutationState<T> get state => _state;

  Future<void> commit() async {
    final key = _state.idempotencyKey ?? _createKey();
    _set(MutationState(phase: MutationPhase.committing, idempotencyKey: key));
    try {
      final value = await _service.execute(key);
      _set(
        MutationState(
          phase: MutationPhase.committed,
          value: value,
          idempotencyKey: key,
        ),
      );
    } on OfflineException {
      _set(
        MutationState(
          phase: MutationPhase.retryableFailure,
          idempotencyKey: key,
        ),
      );
    }
  }

  void _set(MutationState<T> value) {
    _state = value;
    notifyListeners();
  }
}
