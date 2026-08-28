// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/profile/domain/model.dart';
import '../api/pending_command_store.dart';
import '../cache/read_cache.dart';
import 'app_runtime.dart';
import 'member_bootstrap.dart';
import 'member_feature_scope.dart';

typedef MemberBootstrapRefresher = Future<MemberBootstrap> Function();

/// Owns the member feature scope after entry has produced a completed bootstrap.
///
/// This runtime has no knowledge of authentication, sessions, generated API
/// clients, or platform storage. Production supplies those concerns outside
/// this provider-neutral boundary.
class MemberShellRuntime extends ChangeNotifier implements AppRuntime {
  MemberShellRuntime.managed({
    required ScopedReadCacheStorage cacheStorage,
    required PendingCommandStore pendingCommandStore,
    required MemberFeatureScopeFactory featureScopeFactory,
  }) : _cacheStorage = cacheStorage,
       _pendingCommandStore = pendingCommandStore,
       _featureScopeFactory = featureScopeFactory;

  factory MemberShellRuntime.completed({
    required MemberBootstrap bootstrap,
    required MemberFeatureScope featureScope,
    MemberBootstrapRefresher? refreshBootstrap,
    Future<void> Function()? onDeletionAccepted,
    Future<void> Function(int expectedGeneration)? onResetAccepted,
  }) {
    if (!bootstrap.canEnterMemberShell) {
      throw ArgumentError.value(
        bootstrap,
        'bootstrap',
        'A completed member bootstrap is required.',
      );
    }
    final expectedScope = CacheScope(
      accountId: bootstrap.accountId,
      resetGeneration: bootstrap.resetGeneration,
    );
    if (featureScope.scope != expectedScope) {
      throw ArgumentError.value(
        featureScope.scope,
        'featureScope',
        'The feature scope must match the completed bootstrap.',
      );
    }
    final runtime = MemberShellRuntime._completed(
      bootstrap: bootstrap,
      featureScope: featureScope,
      refreshBootstrap: refreshBootstrap,
      onDeletionAccepted: onDeletionAccepted,
      onResetAccepted: onResetAccepted,
    );
    runtime._bindScopeLifecycle();
    featureScope.updateBootstrap(bootstrap);
    return runtime;
  }

  MemberShellRuntime._completed({
    required MemberBootstrap bootstrap,
    required MemberFeatureScope featureScope,
    required MemberBootstrapRefresher? refreshBootstrap,
    required Future<void> Function()? onDeletionAccepted,
    required Future<void> Function(int expectedGeneration)? onResetAccepted,
  }) : _cacheStorage = null,
       _pendingCommandStore = null,
       _featureScopeFactory = null,
       _memberBootstrap = bootstrap,
       _featureScope = featureScope,
       _refreshBootstrap = refreshBootstrap,
       _onDeletionAccepted = onDeletionAccepted,
       _onResetAccepted = onResetAccepted;

  final ScopedReadCacheStorage? _cacheStorage;
  final PendingCommandStore? _pendingCommandStore;
  final MemberFeatureScopeFactory? _featureScopeFactory;
  MemberBootstrapRefresher? _refreshBootstrap;
  Future<void> Function()? _onDeletionAccepted;
  Future<void> Function(int expectedGeneration)? _onResetAccepted;
  MemberBootstrap? _memberBootstrap;
  MemberFeatureScope? _featureScope;
  ScopedReadCache? _scopedReadCache;
  MemberFeatureScope? _retiredScope;
  bool _legacyMutationsCleared = false;
  bool _isDisposed = false;

  @override
  MemberEntryGate get entryGate =>
      _memberBootstrap?.canEnterMemberShell == true && _featureScope != null
      ? MemberEntryGate.member
      : MemberEntryGate.restoring;

  @override
  MemberBootstrap? get memberBootstrap => _memberBootstrap;

  @override
  MemberFeatureScope? get featureScope => _featureScope;

  @override
  CacheScope? get activeCacheScope => _featureScope?.scope;

  void configureLifecycle({
    MemberBootstrapRefresher? refreshBootstrap,
    Future<void> Function()? onDeletionAccepted,
    Future<void> Function(int expectedGeneration)? onResetAccepted,
  }) {
    _refreshBootstrap = refreshBootstrap;
    _onDeletionAccepted = onDeletionAccepted;
    _onResetAccepted = onResetAccepted;
    _bindScopeLifecycle();
  }

  Future<void> transitionTo(MemberBootstrap? next) async {
    _checkActive();
    if (_featureScopeFactory == null ||
        _cacheStorage == null ||
        _pendingCommandStore == null) {
      throw StateError('A completed member runtime cannot change scope.');
    }
    final retired = _retiredScope;
    if (retired != null) {
      try {
        await retired.deactivateSensitiveState();
        retired.dispose();
        _retiredScope = null;
      } on Object {
        if (next != null) rethrow;
      }
    }
    final previous = _memberBootstrap;
    final previousScope = previous == null
        ? null
        : CacheScope(
            accountId: previous.accountId,
            resetGeneration: previous.resetGeneration,
          );
    final nextScope = next == null
        ? null
        : CacheScope(
            accountId: next.accountId,
            resetGeneration: next.resetGeneration,
          );
    final changed =
        previousScope != nextScope ||
        previous?.canEnterMemberShell != next?.canEnterMemberShell;
    if (changed) {
      final oldScope = _featureScope;
      final oldCache = _scopedReadCache;
      _featureScope = null;
      _scopedReadCache = null;
      oldCache?.revoke();
      if (oldScope != null) {
        try {
          await oldScope.deactivateSensitiveState();
          oldScope.dispose();
        } on Object {
          _retiredScope = oldScope;
          _memberBootstrap = null;
          if (next != null) {
            if (oldCache != null) await _bestEffort(oldCache.clear());
            rethrow;
          }
        }
      }
      if (previousScope != null) {
        await Future.wait([
          oldCache == null
              ? _bestEffort(_cacheStorage.clearScope(previousScope))
              : _bestEffort(oldCache.clear()),
          _bestEffort(_pendingCommandStore.clearScope(previousScope)),
        ]);
      } else if (oldCache != null) {
        await _bestEffort(oldCache.clear());
      }
    }
    _memberBootstrap = next;
    if (next != null && next.canEnterMemberShell && _featureScope == null) {
      if (!_legacyMutationsCleared) {
        await _cacheStorage.clearLegacyMutations();
        _legacyMutationsCleared = true;
      }
      final activeScope = nextScope!;
      final scopedCache = ScopedReadCache(
        storage: _cacheStorage,
        scope: activeScope,
      );
      _featureScope = _featureScopeFactory(activeScope, scopedCache, next);
      _scopedReadCache = scopedCache;
      _bindScopeLifecycle();
    }
    if (next != null) _featureScope?.updateBootstrap(next);
    notifyListeners();
  }

  @override
  Future<void> ensureBranchLoaded(MemberBranch branch) =>
      _requireScope().load(branch);

  @override
  Future<bool> updateMemberPreferences(ProfilePreferencesUpdate update) async {
    final saved = await _requireScope().profileController.updatePreferences(
      update,
    );
    if (!saved) return false;
    return _refreshAfterProfileMutation();
  }

  @override
  Future<bool> updateMemberInvestor(ProfileInvestorUpdate update) async {
    final saved = await _requireScope().profileController.updateInvestor(
      update,
    );
    if (!saved) return false;
    return _refreshAfterProfileMutation();
  }

  @override
  Future<bool> updateMemberAstrology(ProfileAstrologyUpdate update) async {
    final saved = await _requireScope().profileController.updateAstrology(
      update,
    );
    if (!saved) return false;
    return _refreshAfterProfileMutation();
  }

  @override
  Future<bool> deleteMemberAstrology({required int expectedVersion}) async {
    final saved = await _requireScope().profileController.deleteAstrology(
      expectedVersion: expectedVersion,
    );
    if (!saved) return false;
    return _refreshAfterProfileMutation();
  }

  Future<bool> _refreshAfterProfileMutation() async {
    final refresh = _refreshBootstrap;
    if (refresh == null) {
      _requireScope().profileController.markBootstrapRefreshFailure();
      return false;
    }
    try {
      final refreshed = await refresh();
      if (_featureScopeFactory == null) {
        final current = _memberBootstrap;
        if (current == null ||
            current.accountId != refreshed.accountId ||
            current.resetGeneration != refreshed.resetGeneration ||
            !refreshed.canEnterMemberShell) {
          throw StateError('The refreshed bootstrap changed account scope.');
        }
        _memberBootstrap = refreshed;
        _featureScope?.updateBootstrap(refreshed);
        notifyListeners();
      } else {
        await transitionTo(refreshed);
      }
      return true;
    } on Object {
      _requireScope().profileController.markBootstrapRefreshFailure();
      return false;
    }
  }

  void _bindScopeLifecycle() {
    final scope = _featureScope;
    if (scope == null) return;
    final deletion = _onDeletionAccepted;
    final reset = _onResetAccepted;
    if (deletion != null && reset != null) {
      scope.privacyController?.bindAccountTransitions(
        onDeletionAccepted: deletion,
        onResetAccepted: reset,
      );
    }
  }

  MemberFeatureScope _requireScope() {
    final value = _featureScope;
    if (value == null) {
      throw StateError(
        'Member feature scope is unavailable before shell entry.',
      );
    }
    return value;
  }

  Future<void> _bestEffort(Future<void> cleanup) async {
    try {
      await cleanup;
    } on Object {
      // Runtime fencing stays authoritative if device cleanup needs retrying.
    }
  }

  void _checkActive() {
    if (_isDisposed) throw StateError('The member shell runtime is disposed.');
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final scopedCache = _scopedReadCache;
    _scopedReadCache = null;
    if (scopedCache != null) {
      scopedCache.revoke();
      unawaited(_bestEffort(scopedCache.clear()));
    }
    _featureScope?.dispose();
    _retiredScope?.dispose();
    _featureScope = null;
    _retiredScope = null;
    super.dispose();
  }
}
