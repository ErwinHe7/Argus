//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/generated/auth/api_key_auth.dart';
import 'package:ritual_investing_api_client/generated/auth/basic_auth.dart';
import 'package:ritual_investing_api_client/generated/auth/bearer_auth.dart';
import 'package:ritual_investing_api_client/generated/auth/oauth.dart';
import 'package:ritual_investing_api_client/generated/api/account_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_moderation_api.dart';
import 'package:ritual_investing_api_client/generated/api/admin_operations_api.dart';
import 'package:ritual_investing_api_client/generated/api/assets_api.dart';
import 'package:ritual_investing_api_client/generated/api/briefings_api.dart';
import 'package:ritual_investing_api_client/generated/api/brokerage_connections_api.dart';
import 'package:ritual_investing_api_client/generated/api/brokerage_orders_api.dart';
import 'package:ritual_investing_api_client/generated/api/brokerage_reads_api.dart';
import 'package:ritual_investing_api_client/generated/api/circles_api.dart';
import 'package:ritual_investing_api_client/generated/api/coven_api.dart';
import 'package:ritual_investing_api_client/generated/api/discover_api.dart';
import 'package:ritual_investing_api_client/generated/api/editorial_api.dart';
import 'package:ritual_investing_api_client/generated/api/future_mirror_api.dart';
import 'package:ritual_investing_api_client/generated/api/intentions_api.dart';
import 'package:ritual_investing_api_client/generated/api/media_api.dart';
import 'package:ritual_investing_api_client/generated/api/member_security_api.dart';
import 'package:ritual_investing_api_client/generated/api/moderation_api.dart';
import 'package:ritual_investing_api_client/generated/api/notifications_api.dart';
import 'package:ritual_investing_api_client/generated/api/platform_api.dart';
import 'package:ritual_investing_api_client/generated/api/privacy_api.dart';
import 'package:ritual_investing_api_client/generated/api/public_api.dart';
import 'package:ritual_investing_api_client/generated/api/rituals_api.dart';
import 'package:ritual_investing_api_client/generated/api/rowan_api.dart';
import 'package:ritual_investing_api_client/generated/api/saved_api.dart';
import 'package:ritual_investing_api_client/generated/api/search_api.dart';
import 'package:ritual_investing_api_client/generated/api/session_api.dart';

class RitualInvestingApiClient {
  static const String basePath =
      r'https://PROJECT_REF.supabase.co/functions/v1/api';

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

  /// Get AdminApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AdminApi getAdminApi() {
    return AdminApi(dio);
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

  /// Get BrokerageConnectionsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  BrokerageConnectionsApi getBrokerageConnectionsApi() {
    return BrokerageConnectionsApi(dio);
  }

  /// Get BrokerageOrdersApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  BrokerageOrdersApi getBrokerageOrdersApi() {
    return BrokerageOrdersApi(dio);
  }

  /// Get BrokerageReadsApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  BrokerageReadsApi getBrokerageReadsApi() {
    return BrokerageReadsApi(dio);
  }

  /// Get CirclesApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  CirclesApi getCirclesApi() {
    return CirclesApi(dio);
  }

  /// Get CovenApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  CovenApi getCovenApi() {
    return CovenApi(dio);
  }

  /// Get DiscoverApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  DiscoverApi getDiscoverApi() {
    return DiscoverApi(dio);
  }

  /// Get EditorialApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  EditorialApi getEditorialApi() {
    return EditorialApi(dio);
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

  /// Get MediaApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  MediaApi getMediaApi() {
    return MediaApi(dio);
  }

  /// Get MemberSecurityApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  MemberSecurityApi getMemberSecurityApi() {
    return MemberSecurityApi(dio);
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

  /// Get PlatformApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PlatformApi getPlatformApi() {
    return PlatformApi(dio);
  }

  /// Get PrivacyApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PrivacyApi getPrivacyApi() {
    return PrivacyApi(dio);
  }

  /// Get PublicApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  PublicApi getPublicApi() {
    return PublicApi(dio);
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

  /// Get SavedApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  SavedApi getSavedApi() {
    return SavedApi(dio);
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
}
