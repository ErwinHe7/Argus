class AdminRuntimeConfig {
  const AdminRuntimeConfig({
    required this.apiBaseUrl,
    required this.auth0Domain,
    required this.auth0ClientId,
    required this.auth0Audience,
  });
  final String apiBaseUrl;
  final String auth0Domain;
  final String auth0ClientId;
  final String auth0Audience;

  factory AdminRuntimeConfig.fromEnvironment() {
    const api = String.fromEnvironment('ADMIN_API_BASE_URL');
    const domain = String.fromEnvironment('AUTH0_DOMAIN');
    const client = String.fromEnvironment('AUTH0_ADMIN_CLIENT_ID');
    const audience = String.fromEnvironment('AUTH0_AUDIENCE');
    if (domain.isEmpty || client.isEmpty || audience.isEmpty) {
      throw const FormatException('Auth0 staff configuration is required.');
    }
    return AdminRuntimeConfig(
      apiBaseUrl: api.isEmpty ? Uri.base.origin : api,
      auth0Domain: domain,
      auth0ClientId: client,
      auth0Audience: audience,
    );
  }
}
