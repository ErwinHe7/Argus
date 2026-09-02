import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/asset_codex/application/controller.dart';
import '../../features/asset_codex/domain/model.dart';
import '../../features/briefings/application/briefing_controller.dart';
import '../../features/brokerage_connection/application/controller.dart';
import '../../features/circles/application/controller.dart';
import '../../features/coven/application/controller.dart';
import '../../features/creators/application/controller.dart';
import '../../features/discover/application/controller.dart';
import '../../features/grimoires/application/controller.dart';
import '../../features/intentions/application/member_scenario_controller.dart';
import '../../features/notifications/application/notification_controller.dart';
import '../../features/orders/application/brokerage_order_controller.dart';
import '../../features/portfolio/application/brokerage_controller.dart';
import '../../features/privacy/application/privacy_controller.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/domain/model.dart';
import '../../features/public_beta/domain/member_capability_policy.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/leonidas_voice_preference_store.dart';
import '../../features/rowan/application/controller.dart';
import '../../features/search/application/controller.dart';
import '../../features/starpath/application/starpath_controller.dart';
import '../cache/read_cache.dart';
import 'member_bootstrap.dart';
import 'member_feature_scope.dart';

export 'member_feature_scope.dart' show MemberBranch;

enum MemberEntryGate { restoring, signedOut, failure, onboarding, member }

/// The provider-neutral contract consumed by member navigation and screens.
///
/// Auth, session restoration, hosted login, and generated API clients belong
/// to the production entry layer and are deliberately absent from this port.
abstract interface class AppRuntime implements Listenable {
  MemberEntryGate get entryGate;
  MemberBootstrap? get memberBootstrap;
  MemberFeatureScope? get featureScope;
  CacheScope? get activeCacheScope;

  Future<void> ensureBranchLoaded(MemberBranch branch);
  Future<bool> updateMemberPreferences(ProfilePreferencesUpdate update);
  Future<bool> updateMemberInvestor(ProfileInvestorUpdate update);
  Future<bool> updateMemberAstrology(ProfileAstrologyUpdate update);
  Future<bool> deleteMemberAstrology({required int expectedVersion});
}

extension AppRuntimeFeatureAccess on AppRuntime {
  MemberCapabilityPolicy get capabilityPolicy =>
      featureScope?.capabilityPolicy ?? MemberCapabilityPolicy.native;

  DailyRitualController get dailyRitualController =>
      _requireScope().dailyRitualController;
  LeonidasVoicePreferencePersistence get leonidasVoicePreferenceStore =>
      _requireScope().leonidasVoicePreferenceStore;
  StarpathController get starpathController =>
      _requireScope().starpathController;
  DiscoverController get discoverController =>
      _requireScope().discoverController;
  CovenController get covenController => _requireScope().covenController;
  ProfileController get profileController => _requireScope().profileController;
  BrokerageConnectionController get brokerageConnectionController => _required(
    _requireScope().brokerageConnectionController,
    'Webull connection is unavailable.',
  );
  BrokeragePortfolioController get brokeragePortfolioController => _required(
    _requireScope().brokeragePortfolioController,
    'Webull portfolio is unavailable.',
  );

  BrokerageOrderController get brokerageOrderController => _required(
    _requireScope().brokerageOrderController,
    'Webull orders are unavailable.',
  );
  MemberScenarioController get memberScenarioController => _required(
    _requireScope().memberScenarioController,
    'Member scenarios are unavailable.',
  );
  BriefingController get briefingController => _required(
    _requireScope().briefingController,
    'Briefings are unavailable.',
  );
  NotificationController get notificationController => _required(
    _requireScope().notificationController,
    'In-app notices are unavailable.',
  );
  PrivacyController get privacyController => _required(
    _requireScope().privacyController,
    'Privacy controls are unavailable.',
  );
  SearchController get searchController =>
      _required(_requireScope().searchController, 'Search is unavailable.');
  SearchController? get optionalSearchController =>
      featureScope?.searchController;
  RowanController get rowanController => _required(
    _requireScope().rowanController,
    'Rowan counsel is unavailable.',
  );
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
  bool get hasCovenResearch => featureScope?.covenRepository != null;
  bool get hasGrimoires => featureScope?.grimoireRepository != null;
  bool get hasCircles => featureScope?.circleRepository != null;
  bool get hasCreators => featureScope?.creatorRepository != null;

  CovenDetailController createCovenDetailController(String entryId) =>
      CovenDetailController(
        entryId: entryId,
        repository: _required(
          _requireScope().covenRepository,
          'Coven detail is unavailable.',
        ),
      );

  GrimoireController createGrimoireController(String grimoireId) =>
      GrimoireController(
        grimoireId: grimoireId,
        repository: _required(
          _requireScope().grimoireRepository,
          'Grimoire detail is unavailable.',
        ),
      );

  CircleTemplateController createCircleTemplateController(String templateId) =>
      CircleTemplateController(
        templateId: templateId,
        repository: _required(
          _requireScope().circleRepository,
          'Circle templates are unavailable.',
        ),
      );

  CreatorController createCreatorController(String creatorId) =>
      CreatorController(
        creatorId: creatorId,
        repository: _required(
          _requireScope().creatorRepository,
          'Seeded creators are unavailable.',
        ),
      );

  CircleListController createCircleListController() => CircleListController(
    repository: _required(
      _requireScope().circleRepository,
      'Private Circles are unavailable.',
    ),
    createKey: createRuntimeCommandKey,
  );

  CircleDetailController createCircleDetailController(String circleId) =>
      CircleDetailController(
        circleId: circleId,
        repository: _required(
          _requireScope().circleRepository,
          'Private Circles are unavailable.',
        ),
      );

  MemberFeatureScope _requireScope() {
    final value = featureScope;
    if (value == null) {
      throw StateError(
        'Member feature scope is unavailable before shell entry.',
      );
    }
    return value;
  }
}

T _required<T>(T? value, String message) {
  if (value == null) throw StateError(message);
  return value;
}

String createRuntimeCommandKey() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
