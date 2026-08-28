import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo-reachable shell graph excludes production providers', () async {
    final result = await Process.run('/bin/sh', const [
      '../scripts/check-demo-import-boundary.sh',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('demo import boundary audit passed'));
  });

  test('mobile provider construction stays in the production factory', () {
    final dependencyContainer = File(
      'lib/core/bootstrap/dependency_container.dart',
    ).readAsStringSync();
    final productionFactory = File(
      'lib/core/bootstrap/production_dependency_container.dart',
    ).readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();

    for (final provider in const [
      'supabase_session_repository.dart',
      'flutter_protected_storage.dart',
      'path_provider',
      'ritual_investing_api_client/generated/api.dart',
      'ritual_auth_interceptor.dart',
    ]) {
      expect(dependencyContainer, isNot(contains(provider)));
      expect(productionFactory, contains(provider));
    }
    expect(mainSource, contains('createProductionDependencyContainer'));
    expect(mainSource.toLowerCase(), isNot(contains('skipauth')));
    expect(mainSource.toLowerCase(), isNot(contains('skip_auth')));
  });
}
