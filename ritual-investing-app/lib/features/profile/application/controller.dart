// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../data/repository.dart';
import '../domain/model.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({required ProfileRepository repository})
    : _repository = repository;
  final ProfileRepository _repository;
  ViewState<ProfileModel> _state = const ViewState(phase: LoadPhase.idle);
  ViewState<ProfileModel> get state => _state;
  String? _message;
  String? get message => _message;
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    _message = null;
    _set(const ViewState(phase: LoadPhase.loading));
    try {
      final result = await _repository.load();
      _setRead(result);
    } on OfflineException {
      _set(const ViewState(phase: LoadPhase.retryableFailure));
    } on LoadFailure catch (failure) {
      _set(ViewState(phase: failure.phase));
    } on Object {
      _set(const ViewState(phase: LoadPhase.terminalFailure));
    }
  }

  Future<bool> updatePreferences(ProfilePreferencesUpdate update) => _mutate(
    () => _repository.updatePreferences(update),
  );

  Future<bool> updateInvestor(ProfileInvestorUpdate update) => _mutate(
    () => _repository.updateInvestor(update),
  );

  Future<bool> updateAstrology(ProfileAstrologyUpdate update) => _mutate(
    () => _repository.updateAstrology(update),
  );

  Future<bool> deleteAstrology({required int expectedVersion}) => _mutate(
    () => _repository.deleteAstrology(expectedVersion: expectedVersion),
  );

  void markBootstrapRefreshFailure() {
    _message =
        'Saved on the server, but the app could not refresh. Try again to apply it here.';
    _set(
      ViewState(
        phase: LoadPhase.retryableFailure,
        value: _state.value,
        committedAt: _state.committedAt,
      ),
    );
  }

  Future<bool> _mutate(
    Future<RepositoryRead<ProfileModel>> Function() action,
  ) async {
    if (_isSaving) return false;
    final previous = _state.value;
    _isSaving = true;
    _message = null;
    _set(ViewState(phase: LoadPhase.loading, value: previous));
    try {
      final result = await action();
      _isSaving = false;
      _setRead(result);
      return true;
    } on OfflineException {
      return _recoverAfterMutationFailure(
        phase: LoadPhase.retryableFailure,
        previous: previous,
        message: 'Could not save. Check your connection and Try again.',
      );
    } on LoadFailure catch (failure) {
      return _recoverAfterMutationFailure(
        phase: failure.phase,
        previous: previous,
        message: failure.phase == LoadPhase.conflict
            ? 'These settings changed elsewhere. Review the latest values and Try again.'
            : 'Could not save these settings. Try again.',
      );
    } on Object {
      return _recoverAfterMutationFailure(
        phase: LoadPhase.terminalFailure,
        previous: previous,
        message: 'Could not save these settings. Try again.',
      );
    }
  }

  Future<bool> _recoverAfterMutationFailure({
    required LoadPhase phase,
    required ProfileModel? previous,
    required String message,
  }) async {
    ProfileModel? authoritative;
    DateTime? committedAt;
    try {
      final refreshed = await _repository.load();
      authoritative = refreshed.value;
      committedAt = refreshed.committedAt;
    } on Object {
      authoritative = previous;
    }
    _isSaving = false;
    _message = message;
    _set(
      ViewState(
        phase: phase,
        value: authoritative,
        committedAt: committedAt,
      ),
    );
    return false;
  }

  void _setRead(RepositoryRead<ProfileModel> result) {
    _message = null;
    _set(
      ViewState(
        phase: result.isStale ? LoadPhase.stale : LoadPhase.ready,
        value: result.value,
        committedAt: result.committedAt,
      ),
    );
  }

  void _set(ViewState<ProfileModel> value) {
    _state = value;
    notifyListeners();
  }
}
