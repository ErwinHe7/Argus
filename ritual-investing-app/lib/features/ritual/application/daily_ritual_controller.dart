// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/daily_ritual_repository.dart';
import '../domain/daily_ritual.dart';

export '../../../core/api/view_state.dart' show LoadPhase;

class DailyRitualController extends ChangeNotifier {
  DailyRitualController({required DailyRitualRepository repository})
    : _repository = repository;

  final DailyRitualRepository _repository;
  ViewState<DailyRitual> _state = const ViewState(phase: LoadPhase.idle);

  ViewState<DailyRitual> get state => _state;

  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      _set(
        ViewState(
          phase: result.isStale ? LoadPhase.stale : LoadPhase.ready,
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

  void _set(ViewState<DailyRitual> value) {
    _state = value;
    notifyListeners();
  }
}
