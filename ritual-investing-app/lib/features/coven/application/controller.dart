// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class CovenController extends ChangeNotifier {
  CovenController({required CovenRepository repository})
    : _repository = repository;
  final CovenRepository _repository;
  ViewState<CovenModel> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<CovenModel> get state => _state;
  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      _set(
        ViewState(
          phase: result.isStale
              ? LoadPhase.stale
              : (result.value.entries.isEmpty
                    ? LoadPhase.empty
                    : LoadPhase.ready),
          value: result.value,
          committedAt: result.committedAt,
        ),
      );
    } on OfflineException {
      _set(const ViewState(phase: LoadPhase.retryableFailure));
    } on LoadFailure catch (failure) {
      _set(ViewState(phase: failure.phase));
    }
  }

  void _set(ViewState<CovenModel> value) {
    _state = value;
    notifyListeners();
  }
}
