// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class RowanController extends ChangeNotifier {
  RowanController({required RowanRepository repository})
    : _repository = repository;

  final RowanRepository _repository;
  ViewState<RowanCounselResult> _state = const ViewState(phase: LoadPhase.idle);
  RowanRequest? _request;

  ViewState<RowanCounselResult> get state => _state;
  RowanRequest? get request => _request;
  bool get blocksUnderlyingResource => false;

  Future<void> explain(RowanRequest request) async {
    _request = request;
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.load(request);
      _state = ViewState(
        phase: value.isStale ? LoadPhase.stale : LoadPhase.ready,
        value: value.value,
        committedAt: value.committedAt,
      );
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }
}
