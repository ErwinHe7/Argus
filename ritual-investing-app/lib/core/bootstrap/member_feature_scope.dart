import 'dart:async';

import '../../features/asset_codex/data/repository.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/circles/data/repository.dart';
import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/creators/data/repository.dart';
import '../../features/discover/application/controller.dart';
import '../../features/entitlements/application/entitlement_controller.dart';
import '../../features/funding/application/contribution_controller.dart';
import '../../features/funding/application/funding_source_controller.dart';
import '../../features/future_mirror/application/future_mirror_controller.dart';
import '../../features/grimoires/data/repository.dart';
import '../../features/intentions/application/intention_controller.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/orders/application/order_controller.dart';
import '../../features/portfolio/application/controller.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/profile/application/controller.dart';
import '../../features/rebalancing/application/rebalance_controller.dart';
import '../../features/recurring/application/recurring_plan_controller.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/search/application/controller.dart';
import '../api/invalidation_bus.dart';
import '../cache/read_cache.dart';
import 'member_bootstrap.dart';

enum MemberBranch { ritual, discover, coven, you }

typedef MemberFeatureScopeFactory = MemberFeatureScope Function(
  CacheScope scope,
  ReadCache cache,
  MemberBootstrap bootstrap,
);

class MemberFeatureScope {
  MemberFeatureScope({
    required this.scope,
    required this.dailyRitualController,
    required this.discoverController,
    required this.covenController,
    required this.profileController,
    required this.portfolioController,
    required this.fundingSourceController,
    required this.contributionController,
    required this.invalidationBus,
    this.assetCodexRepository,
    this.searchController,
    this.rowanController,
    this.covenRepository,
    this.grimoireRepository,
    this.circleRepository,
    this.creatorRepository,
    this.orderController,
    this.recurringPlanController,
    this.rebalanceController,
    this.intentionController,
    this.futureMirrorController,
    this.briefingController,
    this.notificationController,
    this.entitlementController,
    this.privacyController,
  });

  final CacheScope scope;
  final DailyRitualController dailyRitualController;
  final DiscoverController discoverController;
  final CovenController covenController;
  final ProfileController profileController;
  final PortfolioController portfolioController;
  final FundingSourceController fundingSourceController;
  final ContributionController contributionController;
  final InvalidationBus invalidationBus;
  final AssetCodexRepository? assetCodexRepository;
  final SearchController? searchController;
  final RowanController? rowanController;
  final CovenRepository? covenRepository;
  final GrimoireRepository? grimoireRepository;
  final CircleRepository? circleRepository;
  final CreatorRepository? creatorRepository;
  final OrderController? orderController;
  final RecurringPlanController? recurringPlanController;
  final RebalanceController? rebalanceController;
  final IntentionController? intentionController;
  final FutureMirrorController? futureMirrorController;
  final BriefingController? briefingController;
  final NotificationController? notificationController;
  final EntitlementController? entitlementController;
  final PrivacyController? privacyController;
  final Map<MemberBranch, Future<void>> _loads = {};
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void updateBootstrap(MemberBootstrap bootstrap) {
    if (_isDisposed) return;
    discoverController.updatePersonalization(bootstrap.personalization);
    recurringPlanController?.updateRhythm(
      bootstrap.personalization.contributionRhythm,
    );
    futureMirrorController?.updatePersonalization(bootstrap.personalization);
    briefingController?.updatePersonalization(bootstrap.personalization);
    notificationController?.updatePersonalization(bootstrap.personalization);
    entitlementController?.updatePersonalization(bootstrap.personalization);
    privacyController?.updatePersonalization(bootstrap.personalization);
    intentionController?.updateProfile(profileController.state.value?.investor);
  }

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
            fundingSourceController.load(),
          ]);
          intentionController?.updateProfile(
            profileController.state.value?.investor,
          );
      }
    });
  }

  Future<void> deactivateSensitiveState() async {
    await privacyController?.deactivate();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    dailyRitualController.dispose();
    discoverController.dispose();
    covenController.dispose();
    profileController.dispose();
    portfolioController.dispose();
    fundingSourceController.dispose();
    contributionController.dispose();
    orderController?.dispose();
    recurringPlanController?.dispose();
    rebalanceController?.dispose();
    intentionController?.dispose();
    futureMirrorController?.dispose();
    briefingController?.dispose();
    notificationController?.dispose();
    entitlementController?.dispose();
    privacyController?.dispose();
    unawaited(invalidationBus.dispose());
    searchController?.dispose();
    rowanController?.dispose();
  }
}
