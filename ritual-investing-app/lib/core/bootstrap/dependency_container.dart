// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import '../../features/asset_codex/application/controller.dart';
import '../../features/asset_codex/data/repository.dart';
import '../../features/asset_codex/domain/model.dart';
import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/discover/application/controller.dart';
import '../../features/discover/data/repository.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/application/controller.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/rowan/data/repository.dart';
import '../../features/search/application/controller.dart';
import '../../features/search/data/repository.dart';
import '../api/ritual_api.dart';
import '../api/flutter_protected_storage.dart';
import '../api/pending_command_store.dart';
import '../auth/auth0_session_repository.dart';
import '../auth/auth_controller.dart';
import '../cache/read_cache.dart';
import '../config/runtime_config.dart';
import 'entry_coordinator.dart';
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
    this.assetCodexRepository,
    this.searchController,
    this.rowanController,
  });

  final CacheScope scope;
  final DailyRitualController dailyRitualController;
  final DiscoverController discoverController;
  final CovenController covenController;
  final ProfileController profileController;
  final PortfolioController portfolioController;
  final AssetCodexRepository? assetCodexRepository;
  final SearchController? searchController;
  final RowanController? rowanController;
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
    searchController?.dispose();
    rowanController?.dispose();
  }
}

class DependencyContainer extends ChangeNotifier {
  DependencyContainer({
    required this.authController,
    required SessionBootstrapService sessionBootstrapService,
    required ScopedReadCacheStorage cacheStorage,
    required PendingCommandStore pendingCommandStore,
    required MemberFeatureScopeFactory featureScopeFactory,
    this.entryCoordinator,
    OnboardingController? onboardingController,
  }) : _sessionBootstrapService = sessionBootstrapService,
       _cacheStorage = cacheStorage,
       _pendingCommandStore = pendingCommandStore,
       _featureScopeFactory = featureScopeFactory,
       onboardingController = onboardingController ?? OnboardingController() {
    entryCoordinator?.bindApplyBootstrap(_transitionTo);
    entryCoordinator?.addListener(_handleEntryCoordinator);
    _recoverySubscription = authController.recoveredSessions.listen((_) {
      final coordinator = entryCoordinator;
      if (coordinator != null) {
        unawaited(coordinator.resumeRecoveredSession());
        return;
      }
      _recoveryPending = true;
      _drainRecoveredSession();
    });
  }

  final AuthController authController;
  final SessionBootstrapService _sessionBootstrapService;
  final ScopedReadCacheStorage _cacheStorage;
  final PendingCommandStore _pendingCommandStore;
  final MemberFeatureScopeFactory _featureScopeFactory;
  final EntryCoordinator? entryCoordinator;
  final OnboardingController onboardingController;
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
    final entry = entryCoordinator;
    if (entry != null) {
      return switch (entry.state.destination) {
        EntryDestination.restoring ||
        EntryDestination.finalizing => MemberEntryGate.restoring,
        EntryDestination.welcome ||
        EntryDestination.questionnaire ||
        EntryDestination.review => MemberEntryGate.signedOut,
        EntryDestination.failure => MemberEntryGate.failure,
        EntryDestination.reconcile ||
        EntryDestination.authenticatedRecovery => MemberEntryGate.onboarding,
        EntryDestination.entitlementBlocked => MemberEntryGate.entitlement,
        EntryDestination.shell => MemberEntryGate.member,
      };
    }
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
  SearchController get searchController {
    final value = _requireScope().searchController;
    if (value == null) throw StateError('Search is unavailable.');
    return value;
  }

  SearchController? get optionalSearchController =>
      _featureScope?.searchController;

  RowanController get rowanController {
    final value = _requireScope().rowanController;
    if (value == null) throw StateError('Rowan counsel is unavailable.');
    return value;
  }

  RowanController? get optionalRowanController =>
      _featureScope?.rowanController;

  AssetCodexController createAssetCodexController({
    required String assetId,
    required AssetSourceContext source,
  }) {
    final repository = _requireScope().assetCodexRepository;
    if (repository == null) throw StateError('Asset Codex is unavailable.');
    return AssetCodexController(
      repository: repository,
      assetId: assetId,
      source: source,
    );
  }

  bool get hasAssetCodex => _featureScope?.assetCodexRepository != null;

  Future<void> bootstrap() {
    final coordinator = entryCoordinator;
    if (coordinator != null) return coordinator.restore();
    return _runRestoration(() async {
      await authController.restore();
      await _loadAuthenticatedState();
    });
  }

  Future<void> login() {
    final coordinator = entryCoordinator;
    if (coordinator != null) return coordinator.signIn();
    return _runRestoration(() async {
      await authController.login();
      await _loadAuthenticatedState();
    });
  }

  Future<void> persistOnboardingDraft(OnboardingDraft draft) async {
    await entryCoordinator?.saveDraft(draft);
  }

  Future<void> beginQuestionnaire() async {
    final coordinator = entryCoordinator;
    if (coordinator == null) {
      throw StateError('Guided onboarding is unavailable.');
    }
    await coordinator.beginQuestionnaire(onboardingController.draft);
  }

  Future<void> createAccount() async {
    final coordinator = entryCoordinator;
    if (coordinator == null) {
      throw StateError('Guided onboarding is unavailable.');
    }
    await coordinator.createAccount(onboardingController.draft);
  }

  Future<void> attachOnboardingDraft() async {
    final coordinator = entryCoordinator;
    if (coordinator == null) {
      throw StateError('Guided onboarding is unavailable.');
    }
    await coordinator.attachDraft();
  }

  Future<void> retryEntryAction() async {
    final coordinator = entryCoordinator;
    if (coordinator == null) return bootstrap();
    switch (coordinator.state.retryAction) {
      case EntryRetryAction.discardDraft:
        await coordinator.discardDraft();
      case EntryRetryAction.restore || null:
        await coordinator.restore();
    }
  }

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
    final coordinator = entryCoordinator;
    if (coordinator != null) {
      await coordinator.logout();
      return;
    }
    await _transitionTo(null);
    await authController.logout();
    notifyListeners();
  }

  Future<void> ensureBranchLoaded(MemberBranch branch) =>
      _requireScope().load(branch);

  Future<bool> updateMemberPreferences(ProfilePreferencesUpdate update) async {
    final saved = await profileController.updatePreferences(update);
    if (!saved) return false;
    if (update.theme != null && !await _refreshMemberBootstrap()) return false;
    return true;
  }

  Future<bool> updateMemberAstrology(ProfileAstrologyUpdate update) async {
    final saved = await profileController.updateAstrology(update);
    if (!saved) return false;
    return _refreshMemberBootstrap();
  }

  Future<bool> deleteMemberAstrology({required int expectedVersion}) async {
    final saved = await profileController.deleteAstrology(
      expectedVersion: expectedVersion,
    );
    if (!saved) return false;
    return _refreshMemberBootstrap();
  }

  Future<bool> _refreshMemberBootstrap() async {
    try {
      final coordinator = entryCoordinator;
      if (coordinator != null) {
        await coordinator.refreshCompletedBootstrap();
      } else {
        await _transitionTo(await _sessionBootstrapService.bootstrap());
        notifyListeners();
      }
      return true;
    } on Object {
      profileController.markBootstrapRefreshFailure();
      return false;
    }
  }

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

  void _handleEntryCoordinator() {
    final draft = entryCoordinator?.state.draft;
    if (draft != null && draft != onboardingController.draft) {
      onboardingController.replaceDraft(draft);
    }
    notifyListeners();
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
    final onboardingDraftStore = OnboardingDraftStore(
      storage: protectedStorage,
      installation: ProtectedStorageInstallationBinding(
        storage: protectedStorage,
      ),
      now: DateTime.now,
    );
    final entryCoordinator = EntryCoordinator(
      authController: auth,
      bootstrapService: GeneratedSessionBootstrapService(client),
      draftStore: onboardingDraftStore,
      onboardingRepository: GeneratedOnboardingRepository(client),
    );
    return DependencyContainer(
      authController: auth,
      sessionBootstrapService: GeneratedSessionBootstrapService(client),
      cacheStorage: cache,
      pendingCommandStore: PendingCommandStore(storage: protectedStorage),
      entryCoordinator: entryCoordinator,
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
        assetCodexRepository: AssetCodexRepository(
          service: GeneratedAssetCodexService(client),
          cache: scopedCache,
        ),
        searchController: SearchController(
          repository: SearchRepository(service: GeneratedSearchService(client)),
        ),
        rowanController: RowanController(
          repository: RowanRepository(
            service: GeneratedRowanService(client),
            cache: scopedCache,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_recoverySubscription.cancel());
    entryCoordinator?.removeListener(_handleEntryCoordinator);
    _featureScope?.dispose();
    onboardingController.dispose();
    authController.dispose();
    super.dispose();
  }
}
