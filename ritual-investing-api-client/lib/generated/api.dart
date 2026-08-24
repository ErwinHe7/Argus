//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/generated/auth/api_key_auth.dart';
import 'package:ritual_investing_api_client/generated/auth/basic_auth.dart';
import 'package:ritual_investing_api_client/generated/auth/bearer_auth.dart';
import 'package:ritual_investing_api_client/generated/auth/oauth.dart';
import 'package:ritual_investing_api_client/generated/api/account_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_asset_codex_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_assets_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_audit_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_briefing_template_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_catalog_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_circle_template_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_coven_entry_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_evidence_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_grimoire_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_media_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_moderation_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_operations_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_privacy_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_ritual_scenario_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_rowan_script_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_scheduling_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_seeded_community_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_session_api.dart';
import 'package:ritual_investing_api_client/generated/api/assets_api.dart';
import 'package:ritual_investing_api_client/generated/api/briefings_api.dart';
import 'package:ritual_investing_api_client/generated/api/circles_api.dart';
import 'package:ritual_investing_api_client/generated/api/demo_entitlements_api.dart';
import 'package:ritual_investing_api_client/generated/api/discover_api.dart';
import 'package:ritual_investing_api_client/generated/api/founders_coven_api.dart';
import 'package:ritual_investing_api_client/generated/api/future_mirror_api.dart';
import 'package:ritual_investing_api_client/generated/api/intentions_api.dart';
import 'package:ritual_investing_api_client/generated/api/moderation_api.dart';
import 'package:ritual_investing_api_client/generated/api/notifications_api.dart';
import 'package:ritual_investing_api_client/generated/api/orders_api.dart';
import 'package:ritual_investing_api_client/generated/api/platform_api.dart';
import 'package:ritual_investing_api_client/generated/api/portfolios_api.dart';
import 'package:ritual_investing_api_client/generated/api/privacy_api.dart';
import 'package:ritual_investing_api_client/generated/api/public_preview_api.dart';
import 'package:ritual_investing_api_client/generated/api/rebalancing_api.dart';
import 'package:ritual_investing_api_client/generated/api/recurring_plans_api.dart';
import 'package:ritual_investing_api_client/generated/api/rituals_api.dart';
import 'package:ritual_investing_api_client/generated/api/rowan_api.dart';
import 'package:ritual_investing_api_client/generated/api/saves_api.dart';
import 'package:ritual_investing_api_client/generated/api/search_api.dart';
import 'package:ritual_investing_api_client/generated/api/session_api.dart';
import 'package:ritual_investing_api_client/generated/api/simulation_api.dart';

class RitualInvestingApiClient {
  static const String basePath = r'https://api.ritual-investing.example';

  final Dio dio;
  RitualInvestingApiClient({
    Dio? dio,
    String? basePathOverride,
    List<Interceptor>? interceptors,
  }) : this.dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: basePathOverride ?? basePath,
               connectTimeout: const Duration(milliseconds: 5000),
               receiveTimeout: const Duration(milliseconds: 3000),
             ),
           ) {
    if (interceptors == null) {
      this.dio.interceptors.addAll([
        OAuthInterceptor(),
        BasicAuthInterceptor(),
        BearerAuthInterceptor(),
        ApiKeyAuthInterceptor(),
      ]);
    } else {
      this.dio.interceptors.addAll(interceptors);
    }
  }

  void setOAuthToken(String name, String token) {
    if (this.dio.interceptors.any((i) => i is OAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is OAuthInterceptor)
                  as OAuthInterceptor)
              .tokens[name] =
          token;
    }
  }

  /// Removes the OAuth token associated with the given [name].
  ///
  /// If no [OAuthInterceptor] is registered or no token exists for the given
  /// [name], this method has no effect.
  void removeOAuthToken(String name) {
    if (this.dio.interceptors.any((i) => i is OAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is OAuthInterceptor)
              as OAuthInterceptor)
          .tokens
          .remove(name);
    }
  }

  void setBearerAuth(String name, String token) {
    if (this.dio.interceptors.any((i) => i is BearerAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is BearerAuthInterceptor)
                  as BearerAuthInterceptor)
              .tokens[name] =
          token;
    }
  }

  /// Removes the bearer authentication token associated with the given [name].
  ///
  /// If no [BearerAuthInterceptor] is registered or no token exists for the
  /// given [name], this method has no effect.
  void removeBearerAuth(String name) {
    if (this.dio.interceptors.any((i) => i is BearerAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is BearerAuthInterceptor)
              as BearerAuthInterceptor)
          .tokens
          .remove(name);
    }
  }

  void setBasicAuth(String name, String username, String password) {
    if (this.dio.interceptors.any((i) => i is BasicAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is BasicAuthInterceptor)
              as BasicAuthInterceptor)
          .authInfo[name] = BasicAuthInfo(
        username,
        password,
      );
    }
  }

  /// Removes the basic authentication credentials associated with the given [name].
  ///
  /// If no [BasicAuthInterceptor] is registered or no credentials exist for the
  /// given [name], this method has no effect.
  void removeBasicAuth(String name) {
    if (this.dio.interceptors.any((i) => i is BasicAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is BasicAuthInterceptor)
              as BasicAuthInterceptor)
          .authInfo
          .remove(name);
    }
  }

  void setApiKey(String name, String apiKey) {
    if (this.dio.interceptors.any((i) => i is ApiKeyAuthInterceptor)) {
      (this.dio.interceptors.firstWhere(
                    (element) => element is ApiKeyAuthInterceptor,
                  )
                  as ApiKeyAuthInterceptor)
              .apiKeys[name] =
          apiKey;
    }
  }

  /// Removes the API key associated with the given [name].
  ///
  /// If no [ApiKeyAuthInterceptor] is registered or no API key exists for the
  /// given [name], this method has no effect.
  void removeApiKey(String name) {
    if (this.dio.interceptors.any((i) => i is ApiKeyAuthInterceptor)) {
      (this.dio.interceptors.firstWhere(
                (element) => element is ApiKeyAuthInterceptor,
              )
              as ApiKeyAuthInterceptor)
          .apiKeys
          .remove(name);
    }
  }

  /// Get AccountApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AccountApi getAccountApi() {
    return AccountApi(dio);
  }

  /// Get AdminAssetCodexApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminAssetCodexApi getAdminAssetCodexApi() {
    return AdminAssetCodexApi(dio);
  }

  /// Get AdminAssetsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminAssetsApi getAdminAssetsApi() {
    return AdminAssetsApi(dio);
  }

  /// Get AdminAuditApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminAuditApi getAdminAuditApi() {
    return AdminAuditApi(dio);
  }

  /// Get AdminBriefingTemplateApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminBriefingTemplateApi getAdminBriefingTemplateApi() {
    return AdminBriefingTemplateApi(dio);
  }

  /// Get AdminCatalogApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminCatalogApi getAdminCatalogApi() {
    return AdminCatalogApi(dio);
  }

  /// Get AdminCircleTemplateApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminCircleTemplateApi getAdminCircleTemplateApi() {
    return AdminCircleTemplateApi(dio);
  }

  /// Get AdminCovenEntryApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminCovenEntryApi getAdminCovenEntryApi() {
    return AdminCovenEntryApi(dio);
  }

  /// Get AdminEvidenceApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminEvidenceApi getAdminEvidenceApi() {
    return AdminEvidenceApi(dio);
  }

  /// Get AdminGrimoireApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminGrimoireApi getAdminGrimoireApi() {
    return AdminGrimoireApi(dio);
  }

  /// Get AdminMediaApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminMediaApi getAdminMediaApi() {
    return AdminMediaApi(dio);
  }

  /// Get AdminModerationApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminModerationApi getAdminModerationApi() {
    return AdminModerationApi(dio);
  }

  /// Get AdminOperationsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminOperationsApi getAdminOperationsApi() {
    return AdminOperationsApi(dio);
  }

  /// Get AdminPrivacyApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminPrivacyApi getAdminPrivacyApi() {
    return AdminPrivacyApi(dio);
  }

  /// Get AdminRitualScenarioApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminRitualScenarioApi getAdminRitualScenarioApi() {
    return AdminRitualScenarioApi(dio);
  }

  /// Get AdminRowanScriptApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminRowanScriptApi getAdminRowanScriptApi() {
    return AdminRowanScriptApi(dio);
  }

  /// Get AdminSchedulingApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminSchedulingApi getAdminSchedulingApi() {
    return AdminSchedulingApi(dio);
  }

  /// Get AdminSeededCommunityApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminSeededCommunityApi getAdminSeededCommunityApi() {
    return AdminSeededCommunityApi(dio);
  }

  /// Get AdminSessionApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminSessionApi getAdminSessionApi() {
    return AdminSessionApi(dio);
  }

  /// Get AssetsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AssetsApi getAssetsApi() {
    return AssetsApi(dio);
  }

  /// Get BriefingsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  BriefingsApi getBriefingsApi() {
    return BriefingsApi(dio);
  }

  /// Get CirclesApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  CirclesApi getCirclesApi() {
    return CirclesApi(dio);
  }

  /// Get DemoEntitlementsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  DemoEntitlementsApi getDemoEntitlementsApi() {
    return DemoEntitlementsApi(dio);
  }

  /// Get DiscoverApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  DiscoverApi getDiscoverApi() {
    return DiscoverApi(dio);
  }

  /// Get FoundersCovenApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  FoundersCovenApi getFoundersCovenApi() {
    return FoundersCovenApi(dio);
  }

  /// Get FutureMirrorApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  FutureMirrorApi getFutureMirrorApi() {
    return FutureMirrorApi(dio);
  }

  /// Get IntentionsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  IntentionsApi getIntentionsApi() {
    return IntentionsApi(dio);
  }

  /// Get ModerationApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  ModerationApi getModerationApi() {
    return ModerationApi(dio);
  }

  /// Get NotificationsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  NotificationsApi getNotificationsApi() {
    return NotificationsApi(dio);
  }

  /// Get OrdersApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  OrdersApi getOrdersApi() {
    return OrdersApi(dio);
  }

  /// Get PlatformApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PlatformApi getPlatformApi() {
    return PlatformApi(dio);
  }

  /// Get PortfoliosApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PortfoliosApi getPortfoliosApi() {
    return PortfoliosApi(dio);
  }

  /// Get PrivacyApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PrivacyApi getPrivacyApi() {
    return PrivacyApi(dio);
  }

  /// Get PublicPreviewApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PublicPreviewApi getPublicPreviewApi() {
    return PublicPreviewApi(dio);
  }

  /// Get RebalancingApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  RebalancingApi getRebalancingApi() {
    return RebalancingApi(dio);
  }

  /// Get RecurringPlansApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  RecurringPlansApi getRecurringPlansApi() {
    return RecurringPlansApi(dio);
  }

  /// Get RitualsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  RitualsApi getRitualsApi() {
    return RitualsApi(dio);
  }

  /// Get RowanApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  RowanApi getRowanApi() {
    return RowanApi(dio);
  }

  /// Get SavesApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  SavesApi getSavesApi() {
    return SavesApi(dio);
  }

  /// Get SearchApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  SearchApi getSearchApi() {
    return SearchApi(dio);
  }

  /// Get SessionApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  SessionApi getSessionApi() {
    return SessionApi(dio);
  }

  /// Get SimulationApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  SimulationApi getSimulationApi() {
    return SimulationApi(dio);
  }
}
