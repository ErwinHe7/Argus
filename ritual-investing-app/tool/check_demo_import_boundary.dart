import 'dart:io';

const _rootSources = <String>[
  'lib/core/bootstrap/app_runtime.dart',
  'lib/core/bootstrap/member_shell_runtime.dart',
  'lib/core/navigation/member_app_router.dart',
];

const _forbiddenPackages = <String>[
  'auth0_flutter',
  'dio',
  'flutter_secure_storage',
  'path_provider',
  'ritual_investing_api_client',
  'share_plus',
];

const _forbiddenPaths = <String>[
  '/core/auth/',
  '/core/bootstrap/dependency_container.dart',
  '/core/bootstrap/entry_coordinator.dart',
  '/core/bootstrap/production_',
  '/core/api/flutter_protected_storage.dart',
  '/features/onboarding/data/onboarding_draft_store.dart',
  '/features/privacy/data/private_export_files.dart',
  '/generated/',
  '/generated_',
];

const _forbiddenSourceTokens = <String>[
  'window.localStorage',
  'window.sessionStorage',
  'window.indexedDB',
  'globalThis.localStorage',
  'globalThis.sessionStorage',
  'globalThis.indexedDB',
];

void main(List<String> arguments) {
  final appRoot = Directory.current.path.endsWith('ritual-investing-app')
      ? Directory.current
      : Directory('${Directory.current.path}/ritual-investing-app');
  if (!appRoot.existsSync()) {
    _fail('ritual-investing-app was not found from ${Directory.current.path}');
  }

  final pending = <File>[
    for (final path in _rootSources) File('${appRoot.path}/$path'),
  ];
  final visited = <String>{};
  final importPattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  while (pending.isNotEmpty) {
    final file = pending.removeLast();
    final canonical = file.absolute.path;
    if (!visited.add(canonical)) continue;
    if (!file.existsSync()) {
      _fail('missing demo-reachable source ${_relative(appRoot, file)}');
    }
    final relative = '/${_relative(appRoot, file)}';
    for (final forbidden in _forbiddenPaths) {
      if (relative.contains(forbidden)) {
        _fail('demo graph reaches forbidden source $relative');
      }
    }

    final source = file.readAsStringSync();
    if (source.contains('https://api.just-build-this.app') ||
        source.contains('https://api-beta.just-build-this.app')) {
      _fail('demo graph contains a member API host in $relative');
    }
    for (final token in _forbiddenSourceTokens) {
      if (source.contains(token)) {
        _fail('demo graph uses persistent browser state ($token) in $relative');
      }
    }

    for (final match in importPattern.allMatches(source)) {
      final uri = match.group(1)!;
      if (uri == 'dart:io') {
        _fail('demo graph imports dart:io from $relative');
      }
      if (uri.startsWith('dart:')) continue;
      if (uri.startsWith('package:')) {
        final package = uri.substring('package:'.length).split('/').first;
        if (_forbiddenPackages.contains(package)) {
          _fail('demo graph imports forbidden package $package from $relative');
        }
        if (package != 'ritual_investing_app') continue;
        final packagePath = uri.substring(
          'package:ritual_investing_app/'.length,
        );
        pending.add(File('${appRoot.path}/lib/$packagePath'));
        continue;
      }
      final resolved = file.parent.uri.resolve(uri).toFilePath();
      pending.add(File(resolved));
    }
  }

  final repositoryRoot = appRoot.parent;
  final demoManifest = File(
    '${repositoryRoot.path}/ritual-investing-demo/pubspec.yaml',
  );
  if (!demoManifest.existsSync()) {
    stdout.writeln(
      'demo plugin manifest pending U2; this audit proves the shared source seam only',
    );
  } else {
    final manifest = demoManifest.readAsStringSync();
    for (final package in _forbiddenPackages) {
      if (RegExp('^\\s*$package\\s*:', multiLine: true).hasMatch(manifest)) {
        _fail(
          'standalone demo manifest registers forbidden dependency $package',
        );
      }
    }
  }

  stdout.writeln(
    'demo import boundary audit passed: ${visited.length} transitive Dart sources are provider-neutral',
  );
}

String _relative(Directory root, File file) =>
    file.absolute.path.substring(root.absolute.path.length + 1);

Never _fail(String message) {
  stderr.writeln('demo import boundary audit failed: $message');
  exit(1);
}
