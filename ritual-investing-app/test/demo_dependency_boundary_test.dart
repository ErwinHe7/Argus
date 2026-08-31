import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile provider construction stays in the production factory', () {
    final dependencyContainer = File(
      'lib/core/bootstrap/dependency_container.dart',
    ).readAsStringSync();
    final productionFactory = File(
      'lib/core/bootstrap/production_dependency_container.dart',
    ).readAsStringSync();
    final nativePlatformAdapters = File(
      'lib/core/bootstrap/production_platform_adapters_io.dart',
    ).readAsStringSync();
    final webPlatformAdapters = File(
      'lib/core/bootstrap/production_platform_adapters_web.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    for (final provider in const [
      'supabase_session_repository.dart',
      'ritual_investing_api_client/generated/api.dart',
      'ritual_auth_interceptor.dart',
    ]) {
      expect(dependencyContainer, isNot(contains(provider)));
      expect(productionFactory, contains(provider));
    }
    expect(dependencyContainer, isNot(contains('path_provider')));
    expect(dependencyContainer, isNot(contains('flutter_protected_storage')));
    expect(nativePlatformAdapters, contains('path_provider'));
    expect(nativePlatformAdapters, contains('flutter_protected_storage'));
    expect(webPlatformAdapters, isNot(contains('path_provider')));
    expect(webPlatformAdapters, isNot(contains('flutter_protected_storage')));
    expect(mainSource, contains('createProductionDependencyContainer'));
    expect(mainSource.toLowerCase(), isNot(contains('skipauth')));
    expect(mainSource.toLowerCase(), isNot(contains('skip_auth')));
  });
}
