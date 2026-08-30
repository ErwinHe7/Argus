import 'dart:convert';

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
            'https://just-build-this.app/auth/recovery,'
            'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
    webullCompletionAllowlist:
        webullLinks ??
        'https://just-build-this.app/mobile/webull/complete,'
            'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
  );

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
      Uri.parse('https://just-build-this.app/auth/recovery'),
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
