import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/config/runtime_config.dart';

void main() {
  RuntimeConfig valid({
    String environment = 'prod',
    String apiBaseUrl = 'https://project.supabase.co/functions/v1/api',
    String supabaseUrl = 'https://project.supabase.co',
    String publishableKey = 'sb_publishable_abcdefghijklmnop',
    String? authLinks,
    String? webullLinks,
  }) => RuntimeConfig(
    environment: environment,
    apiBaseUrl: apiBaseUrl,
    supabaseUrl: supabaseUrl,
    supabasePublishableKey: publishableKey,
    argusAuthRedirectAllowlist:
        authLinks ??
        'https://just-build-this.app/mobile/argus-auth/callback,'
            'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
    webullCompletionAllowlist:
        webullLinks ??
        'https://just-build-this.app/mobile/webull/complete,'
            'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
  );

  test('dev accepts an exact loopback Supabase and Edge API pair', () {
    final config = valid(
      environment: 'dev',
      apiBaseUrl: 'http://127.0.0.1:54321/functions/v1/api',
      supabaseUrl: 'http://127.0.0.1:54321',
    );

    expect(config.environment, 'dev');
    expect(config.supabaseUrl, Uri.parse('http://127.0.0.1:54321'));
  });

  test('committed dev profile is loopback-only', () {
    final values = jsonDecode(
      File('config/dev.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final config = RuntimeConfig(
      environment: values['RITUAL_ENVIRONMENT'] as String,
      apiBaseUrl: values['RITUAL_API_BASE_URL'] as String,
      supabaseUrl: values['SUPABASE_URL'] as String,
      supabasePublishableKey: values['SUPABASE_PUBLISHABLE_KEY'] as String,
    );

    expect(config.environment, 'dev');
    expect(config.supabaseUrl.host, '127.0.0.1');
  });

  test('dev rejects hosted, wildcard, and LAN service targets', () {
    for (final host in const [
      'project.supabase.co',
      '0.0.0.0',
      '192.168.1.25',
    ]) {
      expect(
        () => valid(
          environment: 'dev',
          apiBaseUrl: 'http://$host:54321/functions/v1/api',
          supabaseUrl: 'http://$host:54321',
        ),
        throwsA(isA<RuntimeConfigException>()),
        reason: host,
      );
    }
  });

  test('staging and prod reject loopback service targets', () {
    for (final environment in const ['staging', 'prod']) {
      expect(
        () => valid(
          environment: environment,
          apiBaseUrl: 'https://localhost/functions/v1/api',
          supabaseUrl: 'https://localhost',
        ),
        throwsA(isA<RuntimeConfigException>()),
        reason: environment,
      );
    }
  });

  test(
    'runtime environment identifiers are exactly dev, staging, and prod',
    () {
      const key = 'sb_publishable_abcdefghijklmnop';
      final fingerprint = sha256.convert(utf8.encode(key)).toString();
      expect(
        RuntimeConfig(
          environment: 'staging',
          apiBaseUrl:
              'https://abcdefghijklmnopqrst.supabase.co/functions/v1/api',
          supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          supabasePublishableKey: key,
          stagingSupabaseProjectRef: 'abcdefghijklmnopqrst',
          stagingSupabasePublishableKeySha256: fingerprint,
        ).environment,
        'staging',
      );
      expect(valid(environment: 'prod').environment, 'prod');

      expect(
        () => RuntimeConfig(
          environment: 'beta',
          apiBaseUrl:
              'https://abcdefghijklmnopqrst.supabase.co/functions/v1/api',
          supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          supabasePublishableKey: key,
          stagingSupabaseProjectRef: 'abcdefghijklmnopqrst',
          stagingSupabasePublishableKeySha256: fingerprint,
        ),
        throwsA(isA<RuntimeConfigException>()),
      );
    },
  );

  test(
    'committed staging define file preserves the hosted runtime binding',
    () {
      final values = jsonDecode(
        File('config/staging.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final config = RuntimeConfig(
        environment: values['RITUAL_ENVIRONMENT'] as String,
        apiBaseUrl: values['RITUAL_API_BASE_URL'] as String,
        supabaseUrl: values['SUPABASE_URL'] as String,
        supabasePublishableKey: values['SUPABASE_PUBLISHABLE_KEY'] as String,
        stagingSupabaseProjectRef:
            values['STAGING_SUPABASE_PROJECT_REF'] as String,
        stagingSupabasePublishableKeySha256:
            values['STAGING_SUPABASE_PUBLISHABLE_KEY_SHA256'] as String,
      );

      expect(config.environment, 'staging');
    },
  );

  test('prod configuration requires exact HTTPS Supabase values', () {
    expect(
      () => valid(apiBaseUrl: 'http://api.example'),
      throwsA(isA<RuntimeConfigException>()),
    );
    expect(
      () => valid(supabaseUrl: 'https://project.supabase.co/rest/v1'),
      throwsA(isA<RuntimeConfigException>()),
    );
    expect(
      () => valid(publishableKey: 'sb_secret_do_not_ship'),
      throwsA(isA<RuntimeConfigException>()),
    );
    expect(
      () => valid(publishableKey: 'legacy-service-role-jwt'),
      throwsA(isA<RuntimeConfigException>()),
    );
  });

  test('Argus Auth and Webull completion allowlists cannot overlap', () {
    const target = 'https://just-build-this.app/mobile/callback';
    expect(
      () => valid(authLinks: target, webullLinks: target),
      throwsA(isA<RuntimeConfigException>()),
    );

    final value = valid();
    expect(
      value.nativeLinks.preferredArgusAuthRedirect,
      Uri.parse('https://just-build-this.app/mobile/argus-auth/callback'),
    );
    expect(
      value.passwordRecoveryRedirect,
      Uri.parse('https://just-build-this.app/mobile/argus-auth/callback'),
    );
  });

  test('staging requires exact project and publishable-key fingerprint', () {
    const key = 'sb_publishable_abcdefghijklmnop';
    final fingerprint = sha256.convert(utf8.encode(key)).toString();
    expect(
      RuntimeConfig(
        environment: 'staging',
        apiBaseUrl: 'https://abcdefghijklmnopqrst.supabase.co/functions/v1/api',
        supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
        supabasePublishableKey: key,
        stagingSupabaseProjectRef: 'abcdefghijklmnopqrst',
        stagingSupabasePublishableKeySha256: fingerprint,
      ).environment,
      'staging',
    );
    expect(
      () => RuntimeConfig(
        environment: 'staging',
        apiBaseUrl: 'https://abcdefghijklmnopqrst.supabase.co/functions/v1/api',
        supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
        supabasePublishableKey: key,
        stagingSupabaseProjectRef: 'differentprojectrefxx',
        stagingSupabasePublishableKeySha256: fingerprint,
      ),
      throwsA(isA<RuntimeConfigException>()),
    );
  });
}
