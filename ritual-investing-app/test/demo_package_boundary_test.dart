import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'standalone demo manifest and plugin registry exclude production providers',
    () {
      final demoRoot = Directory('../ritual-investing-demo');
      final manifest = File('${demoRoot.path}/pubspec.yaml');
      final plugins = File('${demoRoot.path}/.flutter-plugins-dependencies');

      expect(
        manifest.existsSync(),
        isTrue,
        reason: 'missing standalone demo package',
      );
      final manifestText = manifest.readAsStringSync();
      final pluginText = plugins.existsSync()
          ? jsonEncode(jsonDecode(plugins.readAsStringSync()))
          : '{}';
      for (final forbidden in const [
        'auth0_flutter',
        'flutter_secure_storage',
        'path_provider',
        'share_plus',
        'ritual_investing_api_client',
        'dio',
      ]) {
        expect(manifestText, isNot(contains(forbidden)));
        expect(pluginText, isNot(contains(forbidden)));
      }
    },
  );

  test('browser frame channel never uses a wildcard target origin', () {
    final source = File('../ritual-investing-demo/lib/web_frame_channel.dart')
        .readAsStringSync();

    expect(source, contains('event.targetOrigin'));
    expect(source, contains("import 'dart:js_interop';"));
    expect(source, contains("import 'package:web/web.dart'"));
    expect(source, isNot(contains("import 'dart:html'")));
    expect(source, isNot(contains("postMessage(event.toMessage(), '*')")));
    expect(source, isNot(contains('postMessage(event.toMessage(), "*")')));
  });

  test('demo evidence uses only the reviewed research fixture host', () {
    final source = File('lib/demo/demo_services.dart').readAsStringSync();
    final reviewed = RegExp(
      r'https://research\.ritual-investing\.test/demo/[a-z-]+',
    ).allMatches(source);

    expect(source, isNot(contains('demo.invalid')));
    expect(reviewed.length, 2);
  });
}
