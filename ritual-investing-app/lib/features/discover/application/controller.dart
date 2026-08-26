// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class DiscoverController extends ChangeNotifier {
  DiscoverController({
    required DiscoverRepository repository,
    MemberPersonalization personalization = const MemberPersonalization(),
  }) : _repository = repository,
       _personalization = personalization;
  final DiscoverRepository _repository;
  MemberPersonalization _personalization;
  MemberPersonalization get personalization => _personalization;
  ViewState<DiscoverModel> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<DiscoverModel> get state => _state;

  DiscoverItemView get lead {
    final items = _state.value?.items;
    if (items == null || items.isEmpty) {
      throw StateError('Discover has no editorial lead.');
    }
    return items.first;
  }

  Future<void> load() async {
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      final empty = result.value.items.isEmpty;
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

  void updatePersonalization(MemberPersonalization value) {
    if (_personalization == value) return;
    _personalization = value;
    notifyListeners();
  }

  void _set(ViewState<DiscoverModel> value) {
    _state = value;
    notifyListeners();
  }
}
