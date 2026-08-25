import 'package:ritual_investing_api_client/generated/api.dart';

import '../../features/asset_codex/data/repository.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/briefings/data/repository.dart';
import '../../features/circles/data/repository.dart';
import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/creators/data/repository.dart';
import '../../features/discover/application/controller.dart';
import '../../features/discover/data/repository.dart';
import '../../features/entitlements/application/entitlement_controller.dart';
import '../../features/entitlements/data/repository.dart';
import '../../features/funding/application/contribution_controller.dart';
import '../../features/funding/application/funding_source_controller.dart';
import '../../features/funding/data/repository.dart';
import '../../features/future_mirror/application/future_mirror_controller.dart';
import '../../features/future_mirror/data/repository.dart';
import '../../features/grimoires/data/repository.dart';
import '../../features/intentions/application/intention_controller.dart';
import '../../features/intentions/data/repository.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/notifications/data/repository.dart';
import '../../features/orders/application/order_controller.dart';
import '../../features/orders/data/repository.dart';
import '../../features/portfolio/application/controller.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/privacy/data/repository.dart';
import '../../features/privacy/domain/model.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/data/repository.dart';
import '../../features/rebalancing/application/rebalance_controller.dart';
import '../../features/rebalancing/data/repository.dart';
import '../../features/recurring/application/recurring_plan_controller.dart';
import '../../features/recurring/data/repository.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/rowan/data/repository.dart';
import '../../features/search/application/controller.dart';
import '../../features/search/data/repository.dart';
import '../api/invalidation_bus.dart';
import '../api/pending_command_store.dart';
import '../api/ritual_api.dart';
import '../auth/auth_controller.dart';
import '../auth/member_auth.dart';
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
  });

  final RitualInvestingApiClient client;
  final PendingCommandStore pendingCommandStore;
  final AuthController authController;
  final PrivacyExportRequestStore privacyExportRequestStore;
  final PrivateExportFiles privateExportFiles;
  final String Function() createCommandKey;
  final DateTime Function() now;

  MemberFeatureScope call(
    CacheScope scope,
    ReadCache scopedCache,
    MemberBootstrap bootstrap,
  ) {
    final covenRepository = CovenRepository(
      service: GeneratedCovenApiService(client),
      cache: scopedCache,
    );
    final portfolioService = GeneratedPortfolioApiService(client);
    final portfolioRepository = CachedPortfolioRepository(
      service: portfolioService,
      cache: scopedCache,
    );
    final portfolioController = PortfolioController(
      repository: portfolioRepository,
      bootstrapDefaultPortfolioId: bootstrap.defaultPortfolioId,
      createKey: createCommandKey,
    );
    final fundingRepository = CachedFundingRepository(
      service: portfolioService,
      cache: scopedCache,
    );
    final invalidationBus = InvalidationBus();
    final orderController = OrderController(
      repository: OrderRepository(service: GeneratedOrderApiService(client)),
      portfolioController: portfolioController,
      pendingStore: pendingCommandStore,
      invalidationBus: invalidationBus,
      scope: scope,
      createKey: createCommandKey,
      now: now,
    );
    final recurringPlanController = RecurringPlanController(
      repository: RecurringPlanRepository(
        service: GeneratedRecurringPlanApiService(client),
      ),
      pendingStore: pendingCommandStore,
      scope: scope,
      createKey: createCommandKey,
      now: now,
      rhythm: bootstrap.personalization.contributionRhythm,
      isFundingSourceActive: (sourceId) async {
        final result = await fundingRepository.loadSources();
        return !result.isStale &&
            result.value.items.any(
              (source) => source.id == sourceId && source.isActive,
            );
      },
    );
    final rebalanceController = RebalanceController(
      repository: RebalanceRepository(
        service: GeneratedRebalanceApiService(client),
      ),
      portfolioController: portfolioController,
      pendingStore: pendingCommandStore,
      invalidationBus: invalidationBus,
      scope: scope,
      createKey: createCommandKey,
      now: now,
    );
    final intentionController = IntentionController(
      repository: CachedIntentionRepository(
        service: GeneratedIntentionApiService(client),
        cache: scopedCache,
      ),
      pendingStore: pendingCommandStore,
      invalidationBus: invalidationBus,
      scope: scope,
      createKey: createCommandKey,
      now: now,
    );
    final futureMirrorController = FutureMirrorController(
      repository: CachedFutureMirrorRepository(
        service: GeneratedFutureMirrorApiService(client),
        cache: scopedCache,
      ),
      pendingStore: pendingCommandStore,
      invalidationBus: invalidationBus,
      scope: scope,
      createKey: createCommandKey,
      now: now,
      personalization: bootstrap.personalization,
    );
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
    final entitlementController = EntitlementController(
      repository: CachedEntitlementRepository(
        service: GeneratedEntitlementService(client),
        cache: scopedCache,
      ),
      pendingStore: pendingCommandStore,
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
        }
      },
      onDeletionAccepted: () async {},
      onResetAccepted: (_) async {},
      personalization: bootstrap.personalization,
    );
    return MemberFeatureScope(
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
        personalization: bootstrap.personalization,
      ),
      covenController: CovenController(repository: covenRepository),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: GeneratedProfileApiService(client),
          cache: scopedCache,
        ),
      ),
      portfolioController: portfolioController,
      fundingSourceController: FundingSourceController(
        repository: fundingRepository,
        createKey: createCommandKey,
      ),
      contributionController: ContributionController(
        repository: fundingRepository,
        portfolioController: portfolioController,
        pendingStore: pendingCommandStore,
        invalidationBus: invalidationBus,
        scope: scope,
        createKey: createCommandKey,
        now: now,
        rhythm: bootstrap.personalization.contributionRhythm,
      ),
      orderController: orderController,
      recurringPlanController: recurringPlanController,
      rebalanceController: rebalanceController,
      intentionController: intentionController,
      futureMirrorController: futureMirrorController,
      briefingController: briefingController,
      notificationController: notificationController,
      entitlementController: entitlementController,
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
