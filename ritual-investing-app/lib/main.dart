import 'package:flutter/material.dart';

import 'app/ritual_investing_app.dart';
import 'core/bootstrap/production_dependency_container.dart';
import 'core/config/runtime_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    runApp(
      RitualInvestingApp(
        container: createProductionDependencyContainer(
          RuntimeConfig.fromEnvironment(),
        ),
      ),
    );
  } on RuntimeConfigException catch (error) {
    runApp(_ConfigurationFailureApp(message: error.message));
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
              'Ritual Investing is not configured.\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
