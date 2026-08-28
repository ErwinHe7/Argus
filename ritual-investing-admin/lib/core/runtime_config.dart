class AdminRuntimeConfig {
  const AdminRuntimeConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.authRedirectUrl,
    required this.environment,
  });
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final Uri authRedirectUrl;
  final String environment;

  factory AdminRuntimeConfig.fromEnvironment() {
    const configuredApi = String.fromEnvironment('ADMIN_API_BASE_URL');
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const redirect = String.fromEnvironment(
      'ADMIN_AUTH_REDIRECT_URL',
      defaultValue: 'http://localhost:7357/auth/callback',
    );
    const environment = String.fromEnvironment(
      'ADMIN_ENVIRONMENT',
      defaultValue: 'development',
    );
    if (!{'development', 'test', 'staging'}.contains(environment)) {
      throw const FormatException(
        'The staff dashboard is limited to local or hosted development.',
      );
    }
    if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
      throw const FormatException(
        'Supabase URL and publishable key are required for staff Auth.',
      );
    }
    final parsedSupabase = Uri.tryParse(supabaseUrl);
    final parsedRedirect = Uri.tryParse(redirect);
    if (parsedSupabase == null ||
        !parsedSupabase.hasScheme ||
        parsedRedirect == null ||
        !parsedRedirect.hasScheme) {
      throw const FormatException(
        'Supabase and redirect URLs must be absolute.',
      );
    }
    return AdminRuntimeConfig(
      apiBaseUrl: configuredApi.isEmpty
          ? '${supabaseUrl.replaceAll(RegExp(r'/$'), '')}/functions/v1/api'
          : configuredApi,
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: publishableKey,
      authRedirectUrl: parsedRedirect,
      environment: environment,
    );
  }
}
