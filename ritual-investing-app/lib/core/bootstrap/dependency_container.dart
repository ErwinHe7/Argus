// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/discover/application/controller.dart';
import '../../features/discover/data/repository.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/data/repository.dart';
import '../../features/portfolio/application/controller.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../api/ritual_api.dart';
import '../api/flutter_protected_storage.dart';
import '../api/pending_command_store.dart';
import '../auth/auth0_session_repository.dart';
import '../auth/auth_controller.dart';
import '../cache/read_cache.dart';
import '../config/runtime_config.dart';
import 'member_bootstrap.dart';

enum MemberBranch { ritual, discover, coven, you }

enum MemberEntryGate {
  restoring,
  signedOut,
  failure,
  onboarding,
  entitlement,
  member,
}

typedef MemberFeatureScopeFactory = MemberFeatureScope Function(
  CacheScope scope,
  ReadCache cache,
);

class MemberFeatureScope {
  MemberFeatureScope({
    required this.scope,
    required this.dailyRitualController,
    required this.discoverController,
    required this.covenController,
    required this.profileController,
    required this.portfolioController,
  });

  final CacheScope scope;
  final DailyRitualController dailyRitualController;
  final DiscoverController discoverController;
  final CovenController covenController;
  final ProfileController profileController;
  final PortfolioController portfolioController;
  final Map<MemberBranch, Future<void>> _loads = {};
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  Future<void> load(MemberBranch branch) {
    if (_isDisposed) return Future.value();
    return _loads.putIfAbsent(branch, () async {
      switch (branch) {
        case MemberBranch.ritual:
          await dailyRitualController.load();
        case MemberBranch.discover:
          await discoverController.load();
        case MemberBranch.coven:
          await covenController.load();
        case MemberBranch.you:
          await Future.wait([
            profileController.load(),
            portfolioController.load(),
          ]);
      }
    });
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    dailyRitualController.dispose();
    discoverController.dispose();
    covenController.dispose();
    profileController.dispose();
    portfolioController.dispose();
  }
}

class DependencyContainer extends ChangeNotifier {
  DependencyContainer({
    required this.authController,
    required SessionBootstrapService sessionBootstrapService,
    required ScopedReadCacheStorage cacheStorage,
    required PendingCommandStore pendingCommandStore,
    required MemberFeatureScopeFactory featureScopeFactory,
  }) : _sessionBootstrapService = sessionBootstrapService,
       _cacheStorage = cacheStorage,
       _pendingCommandStore = pendingCommandStore,
       _featureScopeFactory = featureScopeFactory {
    _recoverySubscription = authController.recoveredSessions.listen((_) {
      _recoveryPending = true;
      _drainRecoveredSession();
    });
  }

  final AuthController authController;
  final SessionBootstrapService _sessionBootstrapService;
  final ScopedReadCacheStorage _cacheStorage;
  final PendingCommandStore _pendingCommandStore;
  final MemberFeatureScopeFactory _featureScopeFactory;
  late final StreamSubscription<void> _recoverySubscription;
  MemberBootstrap? _memberBootstrap;
  MemberFeatureScope? _featureScope;
  bool _isRestoring = false;
  bool _recoveryPending = false;
  bool _legacyMutationsCleared = false;

  MemberBootstrap? get memberBootstrap => _memberBootstrap;
  MemberFeatureScope? get featureScope => _featureScope;
  CacheScope? get activeCacheScope => _featureScope?.scope;

  MemberEntryGate get entryGate {
    if (_isRestoring || authController.state.phase == AuthPhase.loading) {
      return MemberEntryGate.restoring;
    }
    return switch (authController.state.phase) {
      AuthPhase.signedOut => MemberEntryGate.signedOut,
      AuthPhase.failure => MemberEntryGate.failure,
      AuthPhase.loading => MemberEntryGate.restoring,
      AuthPhase.signedIn => switch (_memberBootstrap) {
        null => MemberEntryGate.restoring,
        final value when !value.onboarding.isComplete =>
          MemberEntryGate.onboarding,
        final value
            when value.entitlement.status != MemberEntitlementStatus.active =>
          MemberEntryGate.entitlement,
        _ => MemberEntryGate.member,
      },
    };
  }

  DailyRitualController get dailyRitualController =>
      _requireScope().dailyRitualController;
  DiscoverController get discoverController =>
      _requireScope().discoverController;
  CovenController get covenController => _requireScope().covenController;
  ProfileController get profileController => _requireScope().profileController;
  PortfolioController get portfolioController =>
      _requireScope().portfolioController;

  Future<void> bootstrap() => _runRestoration(() async {
    await authController.restore();
    await _loadAuthenticatedState();
  });

  Future<void> login() => _runRestoration(() async {
    await authController.login();
    await _loadAuthenticatedState();
  });

  Future<void> _runRestoration(Future<void> Function() action) async {
    _isRestoring = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isRestoring = false;
      notifyListeners();
      _drainRecoveredSession();
    }
  }

  Future<void> logout() async {
    await _transitionTo(null);
    await authController.logout();
    notifyListeners();
  }

  Future<void> ensureBranchLoaded(MemberBranch branch) =>
      _requireScope().load(branch);

  Future<void> _resumeRecoveredSession() async {
    await _runRestoration(_loadAuthenticatedState);
  }

  void _drainRecoveredSession() {
    if (_isRestoring || !_recoveryPending) return;
    _recoveryPending = false;
    if (authController.state.phase == AuthPhase.signedIn &&
        _memberBootstrap == null) {
      unawaited(_resumeRecoveredSession());
    }
  }

  Future<void> _loadAuthenticatedState() async {
    if (authController.state.phase != AuthPhase.signedIn) {
      await _transitionTo(null);
      return;
    }
    try {
      await _transitionTo(await _sessionBootstrapService.bootstrap());
    } catch (_) {
      await _transitionTo(null);
      authController.markBootstrapFailure();
    }
  }

  Future<void> _transitionTo(MemberBootstrap? next) async {
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
      _featureScope = null;
      oldScope?.dispose();
      _memberBootstrap = next;
      if (previousScope != null) {
        await Future.wait([
          _bestEffort(_cacheStorage.clearScope(previousScope)),
          _bestEffort(_pendingCommandStore.clearScope(previousScope)),
        ]);
      }
    } else {
      _memberBootstrap = next;
    }
    if (next != null && next.canEnterMemberShell && _featureScope == null) {
      if (!_legacyMutationsCleared) {
        await _cacheStorage.clearLegacyMutations();
        _legacyMutationsCleared = true;
      }
      _featureScope = _featureScopeFactory(
        nextScope!,
        ScopedReadCache(storage: _cacheStorage, scope: nextScope),
      );
    }
  }

  Future<void> _bestEffort(Future<void> cleanup) async {
    try {
      await cleanup;
    } on Object {
      // Scope disposal and the new bootstrap fence are authoritative even when
      // device cleanup must be retried by a later transition.
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

  factory DependencyContainer.production(RuntimeConfig config) {
    final cache = MemoryReadCache();
    final protectedStorage = FlutterProtectedStorage();
    final auth = AuthController(
      repository: Auth0SessionRepository.production(
        domain: config.auth0Domain,
        memberClientId: config.auth0ClientId,
        audience: config.auth0Audience,
        useHttpsCallbacks: config.auth0UseHttpsCallbacks,
      ),
    );
    final client = RitualInvestingApiClient(
      basePathOverride: config.apiBaseUrl,
      interceptors: [RitualAuthInterceptor(tokenProvider: auth)],
    );
    return DependencyContainer(
      authController: auth,
      sessionBootstrapService: GeneratedSessionBootstrapService(client),
      cacheStorage: cache,
      pendingCommandStore: PendingCommandStore(storage: protectedStorage),
      featureScopeFactory: (scope, scopedCache) => MemberFeatureScope(
        scope: scope,
        dailyRitualController: DailyRitualController(
          repository: DailyRitualRepository(
            service: GeneratedRitualApiService(client),
            cache: scopedCache,
          ),
        ),
        discoverController: DiscoverController(
          repository: CachedDiscoverRepository(
            service: GeneratedDiscoverApiService(client),
            cache: scopedCache,
          ),
        ),
        covenController: CovenController(
          repository: CachedCovenRepository(
            service: GeneratedCovenApiService(client),
            cache: scopedCache,
          ),
        ),
        profileController: ProfileController(
          repository: CachedProfileRepository(
            service: GeneratedProfileApiService(client),
            cache: scopedCache,
          ),
        ),
        portfolioController: PortfolioController(
          repository: CachedPortfolioRepository(
            service: GeneratedPortfolioApiService(client),
            cache: scopedCache,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_recoverySubscription.cancel());
    _featureScope?.dispose();
    authController.dispose();
    super.dispose();
  }
}
