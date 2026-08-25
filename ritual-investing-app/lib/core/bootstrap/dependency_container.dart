// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import '../../features/asset_codex/application/controller.dart';
import '../../features/asset_codex/domain/model.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/coven/application/controller.dart';
import '../../features/circles/application/controller.dart';
import '../../features/creators/application/controller.dart';
import '../../features/discover/application/controller.dart';
import '../../features/entitlements/application/entitlement_controller.dart';
import '../../features/funding/application/contribution_controller.dart';
import '../../features/funding/application/funding_source_controller.dart';
import '../../features/future_mirror/application/future_mirror_controller.dart';
import '../../features/grimoires/application/controller.dart';
import '../../features/intentions/application/intention_controller.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/orders/application/order_controller.dart';
import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/application/controller.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/privacy/data/private_export_files.dart';
import '../../features/privacy/data/repository.dart';
import '../../features/recurring/application/recurring_plan_controller.dart';
import '../../features/rebalancing/application/rebalance_controller.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/search/application/controller.dart';
import '../api/ritual_api.dart';
import '../api/flutter_protected_storage.dart';
import '../api/pending_command_store.dart';
import '../auth/auth0_session_repository.dart';
import '../auth/auth_controller.dart';
import '../cache/read_cache.dart';
import '../config/runtime_config.dart';
import 'entry_coordinator.dart';
import 'member_bootstrap.dart';
import 'member_feature_scope.dart';
import 'production_member_feature_scope_factory.dart';

export 'member_feature_scope.dart'
    show MemberBranch, MemberFeatureScope, MemberFeatureScopeFactory;

enum MemberEntryGate {
  restoring,
  signedOut,
  failure,
  onboarding,
  entitlement,
  member,
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
  ScopedReadCache? _scopedReadCache;
  MemberFeatureScope? _retiredScope;
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
  FundingSourceController get fundingSourceController =>
      _requireScope().fundingSourceController;
  ContributionController get contributionController =>
      _requireScope().contributionController;
  OrderController get orderController {
    final value = _requireScope().orderController;
    if (value == null) throw StateError('Orders are unavailable.');
    return value;
  }

  RecurringPlanController get recurringPlanController {
    final value = _requireScope().recurringPlanController;
    if (value == null) throw StateError('Recurring plans are unavailable.');
    return value;
  }

  RebalanceController get rebalanceController {
    final value = _requireScope().rebalanceController;
    if (value == null) throw StateError('Rebalancing is unavailable.');
    return value;
  }

  IntentionController get intentionController {
    final value = _requireScope().intentionController;
    if (value == null) throw StateError('Intentions are unavailable.');
    return value;
  }

  FutureMirrorController get futureMirrorController {
    final value = _requireScope().futureMirrorController;
    if (value == null) throw StateError('Future Mirror is unavailable.');
    return value;
  }

  BriefingController get briefingController {
    final value = _requireScope().briefingController;
    if (value == null) throw StateError('Briefings are unavailable.');
    return value;
  }

  NotificationController get notificationController {
    final value = _requireScope().notificationController;
    if (value == null) throw StateError('In-app notices are unavailable.');
    return value;
  }

  EntitlementController get entitlementController {
    final value = _requireScope().entitlementController;
    if (value == null) throw StateError('Demo membership is unavailable.');
    return value;
  }

  PrivacyController get privacyController {
    final value = _requireScope().privacyController;
    if (value == null) throw StateError('Privacy controls are unavailable.');
    return value;
  }

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

  bool get hasSimulatedInvesting =>
      _featureScope?.orderController != null &&
      _featureScope?.recurringPlanController != null &&
      _featureScope?.rebalanceController != null;

  bool get hasIntentionsAndFutureMirror =>
      _featureScope?.intentionController != null &&
      _featureScope?.futureMirrorController != null;

  bool get hasBriefingsAndNotifications =>
      _featureScope?.briefingController != null &&
      _featureScope?.notificationController != null;

  bool get hasDemoMembership => _featureScope?.entitlementController != null;

  bool get hasPrivacyControls => _featureScope?.privacyController != null;

  bool get hasMemberResearch =>
      _featureScope?.covenRepository != null &&
      _featureScope?.grimoireRepository != null &&
      _featureScope?.circleRepository != null &&
      _featureScope?.creatorRepository != null;

  CovenDetailController createCovenDetailController(String entryId) =>
      CovenDetailController(
        entryId: entryId,
        repository:
            _requireScope().covenRepository ??
            (throw StateError('Coven detail is unavailable.')),
      );

  GrimoireController createGrimoireController(String grimoireId) =>
      GrimoireController(
        grimoireId: grimoireId,
        repository:
            _requireScope().grimoireRepository ??
            (throw StateError('Grimoire detail is unavailable.')),
      );

  CircleTemplateController createCircleTemplateController(String templateId) =>
      CircleTemplateController(
        templateId: templateId,
        repository:
            _requireScope().circleRepository ??
            (throw StateError('Circle templates are unavailable.')),
      );

  CreatorController createCreatorController(String creatorId) =>
      CreatorController(
        creatorId: creatorId,
        repository:
            _requireScope().creatorRepository ??
            (throw StateError('Seeded creators are unavailable.')),
      );

  CircleListController createCircleListController() => CircleListController(
    repository:
        _requireScope().circleRepository ??
        (throw StateError('Private Circles are unavailable.')),
    createKey: _newCommandKey,
  );

  CircleDetailController createCircleDetailController(String circleId) =>
      CircleDetailController(
        circleId: circleId,
        repository:
            _requireScope().circleRepository ??
            (throw StateError('Private Circles are unavailable.')),
      );

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
    return _refreshMemberBootstrap();
  }

  Future<bool> updateMemberInvestor(ProfileInvestorUpdate update) async {
    final saved = await profileController.updateInvestor(update);
    if (!saved) return false;
    return _refreshMemberBootstrap();
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
    if (draft == null) {
      onboardingController.reset();
    } else if (draft != onboardingController.draft) {
      onboardingController.replaceDraft(draft);
    }
    notifyListeners();
  }

  Future<void> _transitionTo(MemberBootstrap? next) async {
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
      _memberBootstrap = next;
    } else {
      _memberBootstrap = next;
    }
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
      _featureScope?.entitlementController?.bindAuthorityTransition(() async {
        await _refreshMemberBootstrap();
      });
      _featureScope?.privacyController?.bindAccountTransitions(
        onDeletionAccepted: logout,
        onResetAccepted: _acceptDemoReset,
      );
    }
    if (next != null) _featureScope?.updateBootstrap(next);
  }

  Future<void> _bestEffort(Future<void> cleanup) async {
    try {
      await cleanup;
    } on Object {
      // Scope disposal and the new bootstrap fence are authoritative even when
      // device cleanup must be retried by a later transition.
    }
  }

  Future<void> _acceptDemoReset(int expectedGeneration) async {
    final coordinator = entryCoordinator;
    if (coordinator != null) {
      await coordinator.refreshCompletedBootstrap(
        expectedResetGeneration: expectedGeneration,
      );
    } else {
      final refreshed = await _sessionBootstrapService.bootstrap();
      if (refreshed.resetGeneration != expectedGeneration ||
          !refreshed.canEnterMemberShell) {
        throw StateError('The Demo reset bootstrap did not match its receipt.');
      }
      await _transitionTo(refreshed);
      notifyListeners();
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
    final pendingCommandStore = PendingCommandStore(storage: protectedStorage);
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
      installation: AppContainerInstallationBinding(
        cacheDirectoryProvider: getTemporaryDirectory,
      ),
      now: DateTime.now,
    );
    final privacyExportRequestStore = PrivacyExportRequestStore(
      storage: protectedStorage,
    );
    final privateExportFiles = FlutterPrivateExportFiles();
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
      pendingCommandStore: pendingCommandStore,
      entryCoordinator: entryCoordinator,
      featureScopeFactory: ProductionMemberFeatureScopeFactory(
        client: client,
        pendingCommandStore: pendingCommandStore,
        authController: auth,
        privacyExportRequestStore: privacyExportRequestStore,
        privateExportFiles: privateExportFiles,
        createCommandKey: _newCommandKey,
        now: DateTime.now,
      ).call,
    );
  }

  @override
  void dispose() {
    unawaited(_recoverySubscription.cancel());
    entryCoordinator?.removeListener(_handleEntryCoordinator);
    final scopedCache = _scopedReadCache;
    _scopedReadCache = null;
    if (scopedCache != null) {
      scopedCache.revoke();
      unawaited(_bestEffort(scopedCache.clear()));
    }
    _featureScope?.dispose();
    _retiredScope?.dispose();
    onboardingController.dispose();
    authController.dispose();
    super.dispose();
  }
}

String _newCommandKey() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
