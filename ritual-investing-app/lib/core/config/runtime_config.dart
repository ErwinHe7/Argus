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
    String stagingSupabaseProjectRef = '',
    String stagingSupabasePublishableKeySha256 = '',
    this.allowSelfServiceSignup = false,
    String argusAuthRedirectAllowlist =
        'https://just-build-this.app/mobile/argus-auth/callback,'
        'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
    String webullCompletionAllowlist =
        'https://just-build-this.app/mobile/webull/complete,'
        'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
  }) : apiBaseUrl = _serviceUrl(apiBaseUrl, 'RITUAL_API_BASE_URL', environment),
       supabaseUrl = _supabaseUrl(supabaseUrl, environment),
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
      stagingProjectRef: stagingSupabaseProjectRef,
      stagingKeySha256: stagingSupabasePublishableKeySha256,
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
    stagingSupabaseProjectRef: const String.fromEnvironment(
      'STAGING_SUPABASE_PROJECT_REF',
    ),
    stagingSupabasePublishableKeySha256: const String.fromEnvironment(
      'STAGING_SUPABASE_PUBLISHABLE_KEY_SHA256',
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

  static bool _isLoopbackHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  static String _serviceUrl(String value, String name, String environment) {
    final normalized = _required(value, name);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'https' &&
            !(environment == 'dev' && uri.scheme == 'http')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (environment == 'dev' && !_isLoopbackHost(uri.host)) ||
        (environment != 'dev' && _isLoopbackHost(uri.host))) {
      throw RuntimeConfigException(
        environment == 'dev'
            ? '$name must be an exact loopback HTTP or HTTPS URL.'
            : '$name must be an exact non-loopback HTTPS URL.',
      );
    }
    return normalized;
  }

  static Uri _supabaseUrl(String value, String environment) {
    final normalized = _serviceUrl(value, 'SUPABASE_URL', environment);
    final uri = Uri.parse(normalized);
    if ((environment != 'dev' && uri.hasPort) ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw RuntimeConfigException(
        environment == 'dev'
            ? 'SUPABASE_URL must be a loopback origin without a path.'
            : 'SUPABASE_URL must be a non-loopback HTTPS origin without a path or port.',
      );
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
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
    required String stagingProjectRef,
    required String stagingKeySha256,
    required bool allowSelfServiceSignup,
  }) {
    if (environment != 'dev' &&
        environment != 'staging' &&
        environment != 'prod') {
      throw const RuntimeConfigException(
        'RITUAL_ENVIRONMENT must explicitly be dev, staging, or prod.',
      );
    }
    final api = Uri.parse(apiBaseUrl);
    if (api.origin != supabaseUrl.origin || api.path != '/functions/v1/api') {
      throw const RuntimeConfigException(
        'Auth and Edge API must use the same Supabase project and exact API path.',
      );
    }
    if (environment != 'staging') return;
    if (!RegExp(r'^[a-z]{20}$').hasMatch(stagingProjectRef) ||
        supabaseUrl.host != '$stagingProjectRef.supabase.co') {
      throw const RuntimeConfigException(
        'The staging profile requires its exact Supabase project ref.',
      );
    }
    final fingerprint = sha256.convert(utf8.encode(publishableKey)).toString();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(stagingKeySha256) ||
        fingerprint != stagingKeySha256) {
      throw const RuntimeConfigException(
        'The staging publishable-key fingerprint does not match.',
      );
    }
    if (allowSelfServiceSignup) {
      throw const RuntimeConfigException(
        'Self-service signup is disabled for the invite-first public beta.',
      );
    }
  }
}
