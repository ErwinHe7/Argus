import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import 'application/admin_session_controller.dart';
import 'core/runtime_config.dart';
import 'data/admin_gateway.dart';
import 'ui/admin_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  try {
    final config = AdminRuntimeConfig.fromEnvironment();
    final session = AdminSessionController(
      credentials: Auth0AdminCredentialRepository(
        Auth0(config.auth0Domain, config.auth0ClientId),
        config.auth0Audience,
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
