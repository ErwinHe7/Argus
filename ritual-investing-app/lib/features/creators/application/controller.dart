// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../discover/domain/model.dart';
import '../data/repository.dart';

class CreatorController extends ChangeNotifier {
  CreatorController({
    required this.creatorId,
    required CreatorRepository repository,
  }) : _repository = repository;

  final String creatorId;
  final CreatorRepository _repository;
  ViewState<SeededCreatorView> _state = const ViewState(phase: LoadPhase.idle);

  ViewState<SeededCreatorView> get state => _state;

  Future<void> load() async {
    _state = const ViewState(phase: LoadPhase.loading);
    notifyListeners();
    try {
      final value = await _repository.load(creatorId);
      _state = ViewState(
        phase: value.isStale ? LoadPhase.stale : LoadPhase.ready,
        value: value.value,
        committedAt: value.committedAt,
      );
    } on OfflineException {
      _state = const ViewState(phase: LoadPhase.retryableFailure);
    } on LoadFailure catch (failure) {
      _state = ViewState(phase: failure.phase);
    }
    notifyListeners();
  }
}
