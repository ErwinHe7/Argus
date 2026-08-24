// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class DiscoverController extends ChangeNotifier {
  DiscoverController({required DiscoverRepository repository})
    : _repository = repository;
  final DiscoverRepository _repository;
  ViewState<DiscoverModel> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<DiscoverModel> get state => _state;

  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      final empty =
          result.value.grimoires.isEmpty && result.value.circles.isEmpty;
      _set(
        ViewState(
          phase: result.isStale
              ? LoadPhase.stale
              : (empty ? LoadPhase.empty : LoadPhase.ready),
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

  void _set(ViewState<DiscoverModel> value) {
    _state = value;
    notifyListeners();
  }
}
