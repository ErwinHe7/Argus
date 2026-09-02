import 'dart:async';

import '../../features/asset_codex/data/repository.dart';
import '../../features/ai_analysis/application/controller.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/brokerage_connection/application/controller.dart';
import '../../features/circles/data/repository.dart';
import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/creators/data/repository.dart';
import '../../features/discover/application/controller.dart';
import '../../features/grimoires/data/repository.dart';
import '../../features/intentions/application/member_scenario_controller.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/orders/application/brokerage_order_controller.dart';
import '../../features/portfolio/application/brokerage_controller.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/profile/application/controller.dart';
import '../../features/public_beta/domain/member_capability_policy.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/search/application/controller.dart';
import '../../features/starpath/application/starpath_controller.dart';
import '../api/invalidation_bus.dart';
import '../cache/read_cache.dart';
import 'member_bootstrap.dart';

enum MemberBranch { ritual, starpath, discover, coven, you }

typedef MemberFeatureScopeFactory = MemberFeatureScope Function(
  CacheScope scope,
  ReadCache cache,
  MemberBootstrap bootstrap,
);

class MemberFeatureScope {
  MemberFeatureScope({
    required this.scope,
    required this.dailyRitualController,
    required this.starpathController,
    required this.discoverController,
    required this.covenController,
    required this.profileController,
    required this.invalidationBus,
    this.capabilityPolicy = MemberCapabilityPolicy.native,
    this.brokerageConnectionController,
    this.aiAnalysisController,
    this.brokeragePortfolioController,
    this.assetCodexRepository,
    this.searchController,
    this.rowanController,
    this.covenRepository,
    this.grimoireRepository,
    this.circleRepository,
    this.creatorRepository,
    this.brokerageOrderController,
    this.memberScenarioController,
    this.briefingController,
    this.notificationController,
    this.privacyController,
  });

  final CacheScope scope;
  final DailyRitualController dailyRitualController;
  final StarpathController starpathController;
  final DiscoverController discoverController;
  final AiAnalysisController? aiAnalysisController;
  final CovenController covenController;
  final ProfileController profileController;
  final MemberCapabilityPolicy capabilityPolicy;
  final BrokerageConnectionController? brokerageConnectionController;
  final BrokeragePortfolioController? brokeragePortfolioController;
  final InvalidationBus invalidationBus;
  final AssetCodexRepository? assetCodexRepository;
  final SearchController? searchController;
  final RowanController? rowanController;
  final CovenRepository? covenRepository;
  final GrimoireRepository? grimoireRepository;
  final CircleRepository? circleRepository;
  final CreatorRepository? creatorRepository;
  final BrokerageOrderController? brokerageOrderController;
  final MemberScenarioController? memberScenarioController;
  final BriefingController? briefingController;
  final NotificationController? notificationController;
  final PrivacyController? privacyController;
  final Map<MemberBranch, Future<void>> _loads = {};
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void updateBootstrap(MemberBootstrap bootstrap) {
    if (_isDisposed) return;
    final priorAccount =
        brokerageConnectionController?.snapshot.activeAccountId;
    brokerageConnectionController?.updateBootstrap(bootstrap.brokerage);
    if (priorAccount != bootstrap.brokerage.activeAccountId) {
      brokeragePortfolioController?.clear(
        accountId: bootstrap.brokerage.activeAccountId,
      );
    }
    discoverController.updatePersonalization(bootstrap.personalization);
    briefingController?.updatePersonalization(bootstrap.personalization);
    notificationController?.updatePersonalization(bootstrap.personalization);
    privacyController?.updatePersonalization(bootstrap.personalization);
  }

  Future<void> load(MemberBranch branch) {
    if (_isDisposed) return Future.value();
    return _loads.putIfAbsent(branch, () async {
      switch (branch) {
        case MemberBranch.ritual:
          await dailyRitualController.load();
        case MemberBranch.starpath:
          await starpathController.load();
        case MemberBranch.discover:
          await Future.wait(<Future<void>>[
            discoverController.load(),
            if (aiAnalysisController case final controller?) controller.load(),
          ]);
        case MemberBranch.coven:
          await covenController.load();
        case MemberBranch.you:
          await Future.wait(<Future<void>>[
            profileController.load(),
            if (brokerageConnectionController case final controller?)
              controller.load(),
          ]);
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
    starpathController.dispose();
    discoverController.dispose();
    aiAnalysisController?.dispose();
    covenController.dispose();
    profileController.dispose();
    brokerageConnectionController?.dispose();
    brokeragePortfolioController?.dispose();
    brokerageOrderController?.dispose();
    memberScenarioController?.dispose();
    briefingController?.dispose();
    notificationController?.dispose();
    privacyController?.dispose();
    unawaited(invalidationBus.dispose());
    searchController?.dispose();
    rowanController?.dispose();
  }
}
