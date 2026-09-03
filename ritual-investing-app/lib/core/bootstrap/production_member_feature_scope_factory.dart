import 'package:ritual_investing_api_client/generated/api.dart';

import '../../features/asset_codex/data/generated_asset_codex_api_service.dart';
import '../../features/asset_codex/data/repository.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/briefings/data/generated_briefing_api_service.dart';
import '../../features/briefings/data/repository.dart';
import '../../features/brokerage_connection/application/controller.dart';
import '../../features/brokerage_connection/data/repository.dart';
import '../../features/circles/data/generated_circle_api_service.dart';
import '../../features/circles/data/repository.dart';
import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/creators/data/generated_creator_api_service.dart';
import '../../features/creators/data/repository.dart';
import '../../features/discover/application/controller.dart';
import '../../features/discover/data/repository.dart';
import '../../features/grimoires/data/generated_grimoire_api_service.dart';
import '../../features/grimoires/data/repository.dart';
import '../../features/intentions/application/member_scenario_controller.dart';
import '../../features/intentions/data/member_scenario_repository.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/notifications/data/generated_notification_api_service.dart';
import '../../features/notifications/data/repository.dart';
import '../../features/orders/application/brokerage_order_controller.dart';
import '../../features/orders/data/brokerage_repository.dart';
import '../../features/portfolio/application/brokerage_controller.dart';
import '../../features/portfolio/data/brokerage_repository.dart';
import '../../features/portfolio/data/generated_brokerage_portfolio_api_service.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/privacy/data/generated_privacy_api_service.dart';
import '../../features/privacy/data/repository.dart';
import '../../features/privacy/domain/model.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/data/repository.dart';
import '../../features/public_beta/domain/member_capability_policy.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/data/leonidas_voice_preference_store.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/rowan/data/generated_rowan_api_service.dart';
import '../../features/rowan/data/repository.dart';
import '../../features/search/application/controller.dart';
import '../../features/search/data/generated_search_api_service.dart';
import '../../features/search/data/repository.dart';
import '../../features/starpath/application/starpath_controller.dart';
import '../../features/starpath/data/generated_starpath_api_service.dart';
import '../../features/starpath/data/starpath_repository.dart';
import '../api/invalidation_bus.dart';
import '../api/pending_command_store.dart';
import '../api/ritual_api.dart';
import '../auth/auth_controller.dart';
import '../auth/member_auth.dart';
import '../auth/member_step_up.dart';
import '../cache/read_cache.dart';
import 'member_bootstrap.dart';
import 'member_feature_scope.dart';

class ProductionMemberFeatureScopeFactory {
  const ProductionMemberFeatureScopeFactory({
    required this.client,
    required this.pendingCommandStore,
    required this.authController,
    required this.privacyExportRequestStore,
    required this.privateExportFiles,
    required this.createCommandKey,
    required this.now,
    required this.openBrokerageAuthorization,
    required this.leonidasVoicePreferenceStore,
    this.capabilityPolicy = MemberCapabilityPolicy.native,
  });

  final RitualInvestingApiClient client;
  final PendingCommandStore pendingCommandStore;
  final AuthController authController;
  final PrivacyExportRequestStore privacyExportRequestStore;
  final PrivateExportFiles privateExportFiles;
  final String Function() createCommandKey;
  final DateTime Function() now;
  final OpenBrokerageAuthorization openBrokerageAuthorization;
  final LeonidasVoicePreferencePersistence leonidasVoicePreferenceStore;
  final MemberCapabilityPolicy capabilityPolicy;

  MemberFeatureScope call(
    CacheScope scope,
    ReadCache scopedCache,
    MemberBootstrap bootstrap,
  ) {
    final covenRepository = CovenRepository(
      service: GeneratedCovenApiService(client),
      cache: scopedCache,
    );
    final invalidationBus = InvalidationBus();
    final memberScenarioController = MemberScenarioController(
      repository: MemberScenarioRepository(
        service: GeneratedMemberScenarioApiService(client),
      ),
      createKey: createCommandKey,
    );
    BrokeragePortfolioController? brokeragePortfolioController;
    BrokerageOrderController? brokerageOrderController;
    BrokerageConnectionController? brokerageConnectionController;
    if (capabilityPolicy.permits(MemberCapability.brokerageConnection) &&
        capabilityPolicy.permits(MemberCapability.brokeragePortfolio)) {
      brokeragePortfolioController = BrokeragePortfolioController(
        repository: BrokeragePortfolioRepository(
          service: GeneratedBrokeragePortfolioApiService(client),
        ),
        initialAccountId: bootstrap.brokerage.activeAccountId,
      );
      brokerageConnectionController = BrokerageConnectionController(
        repository: BrokerageConnectionRepository(
          service: GeneratedBrokerageConnectionApiService(client),
        ),
        openAuthorization: openBrokerageAuthorization,
        initial: bootstrap.brokerage,
        onAccountChanging: () async => brokeragePortfolioController!.clear(),
      );
      if (capabilityPolicy.permits(MemberCapability.brokerageOrders)) {
        brokerageOrderController = BrokerageOrderController(
          repository: BrokerageOrderRepository(
            service: GeneratedBrokerageOrderApiService(client),
          ),
          portfolioController: brokeragePortfolioController,
          pendingStore: pendingCommandStore,
          scope: scope,
          createKey: createCommandKey,
          now: now,
        );
      }
    }
    final briefingController = BriefingController(
      repository: CachedBriefingRepository(
        service: GeneratedBriefingService(client),
        cache: scopedCache,
      ),
      invalidationBus: invalidationBus,
      scope: scope,
      personalization: bootstrap.personalization,
    );
    final notificationController = NotificationController(
      repository: CachedNotificationRepository(
        service: GeneratedNotificationService(client),
        cache: scopedCache,
      ),
      pendingStore: pendingCommandStore,
      invalidationBus: invalidationBus,
      scope: scope,
      createKey: createCommandKey,
      now: now,
      personalization: bootstrap.personalization,
    );
    final privacyController = PrivacyController(
      repository: ScopedPrivacyRepository(
        service: GeneratedPrivacyService(client),
        requestStore: privacyExportRequestStore,
        files: privateExportFiles,
        scope: scope,
      ),
      pendingStore: pendingCommandStore,
      scope: scope,
      createKey: createCommandKey,
      reauthenticate: () async {
        try {
          await authController.reauthenticate(const Duration(minutes: 5));
        } on MemberAuthCancelled {
          throw const RecentAuthCancelled();
        } on MemberAuthUnavailable {
          throw const RecentAuthRequired();
        }
      },
      authorizeDeletion: () async {
        try {
          final authorization = await authController.authorizeSensitiveAction(
            SensitiveMemberAction.argusDelete,
          );
          final session = authController.activeSession;
          if (session == null) throw const StepUpUnavailable();
          return authorization.consumeFor(
            action: SensitiveMemberAction.argusDelete,
            session: session,
            now: now(),
          );
        } on MemberAuthCancelled {
          throw const RecentAuthCancelled();
        } on MemberAuthUnavailable {
          throw const RecentAuthRequired();
        } on InvalidStepUpReceipt {
          throw const RecentAuthRequired();
        } on StepUpUnavailable {
          throw const RecentAuthRequired();
        }
      },
      onDeletionAccepted: () async {},
      personalization: bootstrap.personalization,
    );
    return MemberFeatureScope(
      scope: scope,
      capabilityPolicy: capabilityPolicy,
      dailyRitualController: DailyRitualController(
        repository: DailyRitualRepository(
          service: GeneratedRitualApiService(client),
          cache: scopedCache,
          scope: scope,
          effectiveMode: dailyRitualModeFor(
            bootstrap.personalization.ritualMode,
          ),
          now: now,
        ),
      ),
      leonidasVoicePreferenceStore: leonidasVoicePreferenceStore,
      starpathController: StarpathController(
        repository: StarpathRepository(
          service: GeneratedStarpathApiService(client),
          cache: scopedCache,
        ),
        createKey: createCommandKey,
      ),
      discoverController: DiscoverController(
        repository: CachedDiscoverRepository(
          service: GeneratedDiscoverApiService(client),
          cache: scopedCache,
        ),
        personalization: bootstrap.personalization,
      ),
      covenController: CovenController(repository: covenRepository),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: GeneratedProfileApiService(client),
          cache: scopedCache,
        ),
      ),
      brokerageOrderController: brokerageOrderController,
      memberScenarioController: memberScenarioController,
      brokerageConnectionController: brokerageConnectionController,
      brokeragePortfolioController: brokeragePortfolioController,
      briefingController: briefingController,
      notificationController: notificationController,
      privacyController: privacyController,
      invalidationBus: invalidationBus,
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
      covenRepository: covenRepository,
      grimoireRepository: GrimoireRepository(
        service: GeneratedGrimoireService(client),
        cache: scopedCache,
      ),
      circleRepository: CircleRepository(
        service: GeneratedCircleService(client),
        cache: scopedCache,
      ),
      creatorRepository: CreatorRepository(
        service: GeneratedCreatorService(client),
        cache: scopedCache,
      ),
    );
  }
}
