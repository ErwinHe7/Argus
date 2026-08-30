// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/asset_codex/application/controller.dart';
import '../../features/asset_codex/domain/model.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/brokerage_connection/application/controller.dart';
import '../../features/coven/application/controller.dart';
import '../../features/circles/application/controller.dart';
import '../../features/creators/application/controller.dart';
import '../../features/discover/application/controller.dart';
import '../../features/grimoires/application/controller.dart';
import '../../features/intentions/application/member_scenario_controller.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/orders/application/brokerage_order_controller.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/application/brokerage_controller.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/search/application/controller.dart';
import '../api/ritual_api.dart';
import '../api/pending_command_store.dart';
import '../auth/auth_controller.dart';
import '../cache/read_cache.dart';
import 'app_runtime.dart';
import 'entry_coordinator.dart';
import 'member_bootstrap.dart';
import 'member_feature_scope.dart';
import 'member_shell_runtime.dart';

export 'member_feature_scope.dart'
    show MemberBranch, MemberFeatureScope, MemberFeatureScopeFactory;
export 'app_runtime.dart' show AppRuntime, MemberEntryGate;

class DependencyContainer extends ChangeNotifier implements AppRuntime {
  DependencyContainer({
    required this.authController,
    required SessionBootstrapService sessionBootstrapService,
    required ScopedReadCacheStorage cacheStorage,
    required PendingCommandStore pendingCommandStore,
    required MemberFeatureScopeFactory featureScopeFactory,
    this.entryCoordinator,
    OnboardingController? onboardingController,
  }) : _sessionBootstrapService = sessionBootstrapService,
       _memberShellRuntime = MemberShellRuntime.managed(
         cacheStorage: cacheStorage,
         pendingCommandStore: pendingCommandStore,
         featureScopeFactory: featureScopeFactory,
       ),
       onboardingController = onboardingController ?? OnboardingController() {
    _memberShellRuntime.addListener(_handleMemberShellRuntime);
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
  final MemberShellRuntime _memberShellRuntime;
  final EntryCoordinator? entryCoordinator;
  final OnboardingController onboardingController;
  late final StreamSubscription<void> _recoverySubscription;
  bool _isRestoring = false;
  bool _recoveryPending = false;

  MemberShellRuntime get memberShellRuntime => _memberShellRuntime;

  @override
  MemberBootstrap? get memberBootstrap => _memberShellRuntime.memberBootstrap;

  @override
  MemberFeatureScope? get featureScope => _memberShellRuntime.featureScope;

  @override
  CacheScope? get activeCacheScope => _memberShellRuntime.activeCacheScope;

  @override
  MemberEntryGate get entryGate {
    final entry = entryCoordinator;
    if (entry != null) {
      return switch (entry.state.destination) {
        EntryDestination.restoring ||
        EntryDestination.finalizing => MemberEntryGate.restoring,
        EntryDestination.welcome => MemberEntryGate.signedOut,
        EntryDestination.questionnaire || EntryDestination.review =>
          authController.state.phase == AuthPhase.signedIn
              ? MemberEntryGate.onboarding
              : MemberEntryGate.signedOut,
        EntryDestination.failure => MemberEntryGate.failure,
        EntryDestination.reconcile ||
        EntryDestination.authenticatedRecovery => MemberEntryGate.onboarding,
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
      AuthPhase.signedIn => switch (memberBootstrap) {
        null => MemberEntryGate.restoring,
        final value when !value.onboarding.isComplete =>
          MemberEntryGate.onboarding,
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
  BrokerageConnectionController get brokerageConnectionController =>
      _requireScope().brokerageConnectionController ??
      (throw StateError('Webull connection is unavailable.'));
  BrokeragePortfolioController get brokeragePortfolioController =>
      _requireScope().brokeragePortfolioController ??
      (throw StateError('Webull portfolio is unavailable.'));
  BrokerageOrderController get brokerageOrderController =>
      _requireScope().brokerageOrderController ??
      (throw StateError('Webull orders are unavailable.'));

  MemberScenarioController get memberScenarioController =>
      _requireScope().memberScenarioController ??
      (throw StateError('Member scenarios are unavailable.'));

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
      featureScope?.searchController;

  RowanController get rowanController {
    final value = _requireScope().rowanController;
    if (value == null) throw StateError('Rowan counsel is unavailable.');
    return value;
  }

  RowanController? get optionalRowanController => featureScope?.rowanController;

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

  bool get hasAssetCodex => featureScope?.assetCodexRepository != null;

  bool get hasBrokerageOrders => featureScope?.brokerageOrderController != null;

  bool get hasBrokeragePortfolio =>
      featureScope?.brokerageConnectionController != null &&
      featureScope?.brokeragePortfolioController != null;

  bool get hasMemberScenarios => featureScope?.memberScenarioController != null;

  bool get hasBriefingsAndNotifications =>
      featureScope?.briefingController != null &&
      featureScope?.notificationController != null;

  bool get hasPrivacyControls => featureScope?.privacyController != null;

  bool get hasMemberResearch =>
      featureScope?.covenRepository != null &&
      featureScope?.grimoireRepository != null &&
      featureScope?.circleRepository != null &&
      featureScope?.creatorRepository != null;

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
    createKey: createRuntimeCommandKey,
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

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) {
    final coordinator = entryCoordinator;
    if (coordinator != null) {
      return coordinator.signInWithPassword(email: email, password: password);
    }
    return _runRestoration(() async {
      await authController.signInWithPassword(email: email, password: password);
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

  Future<void> createAccountWithPassword({
    required String email,
    required String password,
  }) async {
    final coordinator = entryCoordinator;
    if (coordinator == null) {
      throw StateError('Guided onboarding is unavailable.');
    }
    await coordinator.createAccountWithPassword(
      reviewedDraft: onboardingController.draft,
      email: email,
      password: password,
    );
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

  @override
  Future<void> ensureBranchLoaded(MemberBranch branch) =>
      _requireScope().load(branch);

  @override
  Future<bool> updateMemberPreferences(ProfilePreferencesUpdate update) async {
    final saved = await profileController.updatePreferences(update);
    if (!saved) return false;
    return _refreshMemberBootstrap();
  }

  @override
  Future<bool> updateMemberInvestor(ProfileInvestorUpdate update) async {
    final saved = await profileController.updateInvestor(update);
    if (!saved) return false;
    return _refreshMemberBootstrap();
  }

  @override
  Future<bool> updateMemberAstrology(ProfileAstrologyUpdate update) async {
    final saved = await profileController.updateAstrology(update);
    if (!saved) return false;
    return _refreshMemberBootstrap();
  }

  @override
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
        memberBootstrap == null) {
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

  void _handleMemberShellRuntime() => notifyListeners();

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
    await _memberShellRuntime.transitionTo(next);
    final scope = featureScope;
    scope?.privacyController?.bindAccountTransitions(
      onDeletionAccepted: logout,
    );
  }

  MemberFeatureScope _requireScope() {
    final value = featureScope;
    if (value == null) {
      throw StateError(
        'Member feature scope is unavailable before shell entry.',
      );
    }
    return value;
  }

  @override
  void dispose() {
    unawaited(_recoverySubscription.cancel());
    entryCoordinator?.removeListener(_handleEntryCoordinator);
    _memberShellRuntime.removeListener(_handleMemberShellRuntime);
    _memberShellRuntime.dispose();
    onboardingController.dispose();
    authController.dispose();
    super.dispose();
  }
}
