import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/admin_session_controller.dart';
import 'core/runtime_config.dart';
import 'data/admin_gateway.dart';
import 'ui/admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  try {
    final config = AdminRuntimeConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    final session = AdminSessionController(
      credentials: SupabaseAdminCredentialRepository(
        Supabase.instance.client,
        config.authRedirectUrl,
      ),
    );
    final client = RitualInvestingApiClient(
      basePathOverride: config.apiBaseUrl,
      interceptors: [RitualAuthInterceptor(tokenProvider: session)],
    );
    client.dio.interceptors.add(AdminIdempotencyRetryInterceptor(client.dio));
    client.dio.interceptors.add(
      AdminAuthorizationFailureInterceptor(session.handleAuthorizationDenied),
    );
    runApp(AdminApp(session: session, gateway: OpenApiAdminGateway(client)));
  } on FormatException catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Ritual staff dashboard is not configured.\n${error.message}',
            ),
          ),
        ),
      ),
    );
  }
}
