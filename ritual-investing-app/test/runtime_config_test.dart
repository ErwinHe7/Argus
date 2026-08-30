import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/config/runtime_config.dart';

void main() {
  RuntimeConfig valid({
    String apiBaseUrl = 'https://project.supabase.co/functions/v1/api',
    String supabaseUrl = 'https://project.supabase.co',
    String publishableKey = 'sb_publishable_abcdefghijklmnop',
    String? authLinks,
    String? webullLinks,
  }) => RuntimeConfig(
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

  test('committed beta define file satisfies the runtime binding', () {
    final values = jsonDecode(File('config/beta.json').readAsStringSync())
        as Map<String, dynamic>;
    final config = RuntimeConfig(
      environment: values['RITUAL_ENVIRONMENT'] as String,
      apiBaseUrl: values['RITUAL_API_BASE_URL'] as String,
      supabaseUrl: values['SUPABASE_URL'] as String,
      supabasePublishableKey: values['SUPABASE_PUBLISHABLE_KEY'] as String,
      betaSupabaseProjectRef:
          values['BETA_SUPABASE_PROJECT_REF'] as String,
      betaSupabasePublishableKeySha256:
          values['BETA_SUPABASE_PUBLISHABLE_KEY_SHA256'] as String,
    );

    expect(config.environment, 'beta');
  });

  test('production configuration requires exact HTTPS Supabase values', () {
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

  test(
    'public beta requires exact project and publishable-key fingerprint',
    () {
      const key = 'sb_publishable_abcdefghijklmnop';
      final fingerprint = sha256.convert(utf8.encode(key)).toString();
      expect(
        RuntimeConfig(
          environment: 'beta',
          apiBaseUrl:
              'https://abcdefghijklmnopqrst.supabase.co/functions/v1/api',
          supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          supabasePublishableKey: key,
          betaSupabaseProjectRef: 'abcdefghijklmnopqrst',
          betaSupabasePublishableKeySha256: fingerprint,
        ).environment,
        'beta',
      );
      expect(
        () => RuntimeConfig(
          environment: 'beta',
          apiBaseUrl:
              'https://abcdefghijklmnopqrst.supabase.co/functions/v1/api',
          supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          supabasePublishableKey: key,
          betaSupabaseProjectRef: 'differentprojectrefxx',
          betaSupabasePublishableKeySha256: fingerprint,
        ),
        throwsA(isA<RuntimeConfigException>()),
      );
    },
  );
}
