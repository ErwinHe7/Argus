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
  });
}
