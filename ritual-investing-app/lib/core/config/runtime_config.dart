class RuntimeConfigException implements Exception {
  const RuntimeConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RuntimeConfig {
  RuntimeConfig({
    required String apiBaseUrl,
    required String auth0Domain,
    required String auth0ClientId,
    required String auth0Audience,
    this.auth0UseHttpsCallbacks = true,
  }) : apiBaseUrl = _httpsUrl(apiBaseUrl, 'RITUAL_API_BASE_URL'),
       auth0Domain = _required(auth0Domain, 'AUTH0_DOMAIN'),
       auth0ClientId = _required(auth0ClientId, 'AUTH0_CLIENT_ID'),
       auth0Audience = _httpsUrl(auth0Audience, 'AUTH0_AUDIENCE');

  final String apiBaseUrl;
  final String auth0Domain;
  final String auth0ClientId;
  final String auth0Audience;
  final bool auth0UseHttpsCallbacks;

  factory RuntimeConfig.fromEnvironment() => RuntimeConfig(
    apiBaseUrl: const String.fromEnvironment(
      'RITUAL_API_BASE_URL',
      defaultValue: 'https://api.just-build-this.app',
    ),
    auth0Domain: const String.fromEnvironment('AUTH0_DOMAIN'),
    auth0ClientId: const String.fromEnvironment('AUTH0_CLIENT_ID'),
    auth0Audience: const String.fromEnvironment('AUTH0_AUDIENCE'),
    auth0UseHttpsCallbacks: const bool.fromEnvironment(
      'AUTH0_USE_HTTPS',
      defaultValue: true,
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
        uri.fragment.isNotEmpty) {
      throw RuntimeConfigException('$name must be an HTTPS URL.');
    }
    return normalized;
  }
}
