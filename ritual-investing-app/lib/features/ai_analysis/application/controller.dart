// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

typedef UtcClock = DateTime Function();

class AiAnalysisController extends ChangeNotifier {
  AiAnalysisController({
    required AiAnalysisRepository repository,
    UtcClock? utcClock,
  }) : _repository = repository,
       _utcClock = utcClock ?? _systemUtcNow;

  final AiAnalysisRepository _repository;
  final UtcClock _utcClock;

  ViewState<AiAnalysisSnapshot> _state = const ViewState(phase: LoadPhase.idle);

  ViewState<AiAnalysisSnapshot> get state => _state;

  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final snapshot = await _repository.load();
      final now = _utcClock().toUtc();
      if (!snapshot.isFreshAt(now)) {
        _set(const ViewState(phase: LoadPhase.terminalFailure));
        return;
      }
      _set(
        ViewState(phase: LoadPhase.ready, value: snapshot, committedAt: now),
      );
    } on Object {
      // Fail closed: never retain an earlier risk regime after a failed fetch.
      _set(const ViewState(phase: LoadPhase.retryableFailure));
    }
  }

  void _set(ViewState<AiAnalysisSnapshot> value) {
    _state = value;
    notifyListeners();
  }

  static DateTime _systemUtcNow() => DateTime.now().toUtc();
}
