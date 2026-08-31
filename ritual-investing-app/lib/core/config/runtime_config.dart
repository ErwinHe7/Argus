import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../auth/member_auth.dart';
import 'runtime_platform.dart';

class RuntimeConfigException implements Exception {
  const RuntimeConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RuntimeConfig {
  RuntimeConfig({
    this.environment = 'staging',
    required String apiBaseUrl,
    required String supabaseUrl,
    required String supabasePublishableKey,
    String betaSupabaseProjectRef = '',
    String betaSupabasePublishableKeySha256 = '',
    this.allowSelfServiceSignup = false,
    String argusAuthRedirectAllowlist =
        'https://just-build-this.app/mobile/argus-auth/callback,'
        'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
    String webullCompletionAllowlist =
        'https://just-build-this.app/mobile/webull/complete,'
        'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
  }) : apiBaseUrl = _httpsUrl(apiBaseUrl, 'RITUAL_API_BASE_URL'),
       supabaseUrl = _supabaseUrl(supabaseUrl),
       supabasePublishableKey = _publishableKey(supabasePublishableKey),
       nativeLinks = _nativeLinks(
         argusAuthRedirectAllowlist,
         webullCompletionAllowlist,
       ) {
    _validateBinding(
      environment: environment,
      apiBaseUrl: this.apiBaseUrl,
      supabaseUrl: this.supabaseUrl,
      publishableKey: this.supabasePublishableKey,
      betaProjectRef: betaSupabaseProjectRef,
      betaKeySha256: betaSupabasePublishableKeySha256,
      allowSelfServiceSignup: allowSelfServiceSignup,
    );
  }

  final String environment;
  final String apiBaseUrl;
  final Uri supabaseUrl;
  final String supabasePublishableKey;
  final MemberNativeLinkPolicy nativeLinks;
  final bool allowSelfServiceSignup;

  Uri get googleAuthRedirect =>
      selectArgusAuthRedirect(nativeLinks.argusAuthTargets);

  @Deprecated('Google OAuth is the only member entry flow.')
  Uri get passwordRecoveryRedirect => googleAuthRedirect;

  factory RuntimeConfig.fromEnvironment() => RuntimeConfig(
    environment: const String.fromEnvironment(
      'RITUAL_ENVIRONMENT',
      defaultValue: 'staging',
    ),
    apiBaseUrl: const String.fromEnvironment('RITUAL_API_BASE_URL'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    betaSupabaseProjectRef: const String.fromEnvironment(
      'BETA_SUPABASE_PROJECT_REF',
    ),
    betaSupabasePublishableKeySha256: const String.fromEnvironment(
      'BETA_SUPABASE_PUBLISHABLE_KEY_SHA256',
    ),
    allowSelfServiceSignup: const bool.fromEnvironment(
      'ALLOW_SELF_SERVICE_SIGNUP',
    ),
    argusAuthRedirectAllowlist: const String.fromEnvironment(
      'ARGUS_AUTH_REDIRECT_ALLOWLIST',
      defaultValue:
          'https://just-build-this.app/mobile/argus-auth/callback,'
          'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
    ),
    webullCompletionAllowlist: const String.fromEnvironment(
      'WEBULL_COMPLETION_ALLOWLIST',
      defaultValue:
          'https://just-build-this.app/mobile/webull/complete,'
          'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
    ),
  );

  static String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw RuntimeConfigException('$name is missing or invalid.');
    }
    return normalized;
  }

  static String _httpsUrl(String value, String name) {
    final normalized = _required(value, name);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw RuntimeConfigException('$name must be an exact HTTPS URL.');
    }
    return normalized;
  }

  static Uri _supabaseUrl(String value) {
    final normalized = _httpsUrl(value, 'SUPABASE_URL');
    final uri = Uri.parse(normalized);
    if (uri.hasPort || (uri.path.isNotEmpty && uri.path != '/')) {
      throw const RuntimeConfigException(
        'SUPABASE_URL must be an origin without a path or port.',
      );
    }
    return Uri(scheme: uri.scheme, host: uri.host);
  }

  static String _publishableKey(String value) {
    final normalized = _required(value, 'SUPABASE_PUBLISHABLE_KEY');
    if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]{16,240}$')
        .hasMatch(normalized)) {
      throw const RuntimeConfigException(
        'SUPABASE_PUBLISHABLE_KEY must be a client publishable key.',
      );
    }
    return normalized;
  }

  static MemberNativeLinkPolicy _nativeLinks(
    String argusAuth,
    String webullCompletion,
  ) {
    try {
      return MemberNativeLinkPolicy.parse(
        argusAuthAllowlist: argusAuth,
        webullCompletionAllowlist: webullCompletion,
      );
    } on FormatException {
      throw const RuntimeConfigException(
        'Native callback allowlists are missing, unsafe, overlapping, or invalid.',
      );
    }
  }

  static void _validateBinding({
    required String environment,
    required String apiBaseUrl,
    required Uri supabaseUrl,
    required String publishableKey,
    required String betaProjectRef,
    required String betaKeySha256,
    required bool allowSelfServiceSignup,
  }) {
    if (environment != 'staging' && environment != 'beta') {
      throw const RuntimeConfigException(
        'RITUAL_ENVIRONMENT must explicitly be staging or beta.',
      );
    }
    final api = Uri.parse(apiBaseUrl);
    if (api.host != supabaseUrl.host || api.path != '/functions/v1/api') {
      throw const RuntimeConfigException(
        'Auth and Edge API must use the same Supabase project and exact API path.',
      );
    }
    if (environment != 'beta') return;
    if (!RegExp(r'^[a-z]{20}$').hasMatch(betaProjectRef) ||
        supabaseUrl.host != '$betaProjectRef.supabase.co') {
      throw const RuntimeConfigException(
        'The public beta requires its exact Supabase branch project ref.',
      );
    }
    final fingerprint = sha256.convert(utf8.encode(publishableKey)).toString();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(betaKeySha256) ||
        fingerprint != betaKeySha256) {
      throw const RuntimeConfigException(
        'The public beta publishable-key fingerprint does not match.',
      );
    }
    if (allowSelfServiceSignup) {
      throw const RuntimeConfigException(
        'Self-service signup is disabled for the invite-first public beta.',
      );
    }
  }
}
