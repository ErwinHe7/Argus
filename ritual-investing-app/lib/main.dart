import 'package:flutter/material.dart';

import 'app/ritual_investing_app.dart';
import 'core/auth/supabase_session_repository.dart';
import 'core/bootstrap/production_dependency_container.dart';
import 'core/config/runtime_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = RuntimeConfig.fromEnvironment();
    final memberSupabase = await initializeMemberSupabase(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      nativeLinks: config.nativeLinks,
    );
    runApp(
      RitualInvestingApp(
        container: createProductionDependencyContainer(
          config,
          initialPasswordRecovery: memberSupabase.initialPasswordRecovery,
        ),
        allowSelfServiceSignup: config.allowSelfServiceSignup,
      ),
    );
  } on RuntimeConfigException catch (error) {
    runApp(_ConfigurationFailureApp(message: error.message));
  } on Object {
    runApp(
      const _ConfigurationFailureApp(
        message: 'Secure member authentication could not be initialized.',
      ),
    );
  }
}

class _ConfigurationFailureApp extends StatelessWidget {
  const _ConfigurationFailureApp({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Leo is not configured.\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
