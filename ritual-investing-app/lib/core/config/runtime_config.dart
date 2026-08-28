import '../auth/member_auth.dart';

class RuntimeConfigException implements Exception {
  const RuntimeConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RuntimeConfig {
  RuntimeConfig({
    required String apiBaseUrl,
    required String supabaseUrl,
    required String supabasePublishableKey,
    String memberAuthProviders = 'google,apple',
    String argusAuthRedirectAllowlist =
        'https://just-build-this.app/mobile/argus-auth/callback,'
        'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
    String webullCompletionAllowlist =
        'https://just-build-this.app/mobile/webull/complete,'
        'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
  }) : apiBaseUrl = _httpsUrl(apiBaseUrl, 'RITUAL_API_BASE_URL'),
       supabaseUrl = _supabaseUrl(supabaseUrl),
       supabasePublishableKey = _publishableKey(supabasePublishableKey),
       memberAuthProviders = _providers(memberAuthProviders),
       nativeLinks = _nativeLinks(
         argusAuthRedirectAllowlist,
         webullCompletionAllowlist,
       );

  final String apiBaseUrl;
  final Uri supabaseUrl;
  final String supabasePublishableKey;
  final MemberAuthProviderAllowlist memberAuthProviders;
  final MemberNativeLinkPolicy nativeLinks;

  factory RuntimeConfig.fromEnvironment() => RuntimeConfig(
    apiBaseUrl: const String.fromEnvironment('RITUAL_API_BASE_URL'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    memberAuthProviders: const String.fromEnvironment(
      'SUPABASE_AUTH_PROVIDERS',
      defaultValue: 'google,apple',
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

  static MemberAuthProviderAllowlist _providers(String value) {
    try {
      return MemberAuthProviderAllowlist.parse(value);
    } on FormatException {
      throw const RuntimeConfigException(
        'SUPABASE_AUTH_PROVIDERS must contain only apple and google.',
      );
    }
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
}
