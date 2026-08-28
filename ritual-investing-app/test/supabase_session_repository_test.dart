import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/auth/member_step_up.dart';
import 'package:ritual_investing_app/core/auth/supabase_session_repository.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _otherUserId = '22222222-2222-4222-8222-222222222222';
const _sessionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _newSessionId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
final _now = DateTime.utc(2026, 8, 28, 12);

void main() {
  group('SupabaseSessionRepository', () {
    test(
      'sign-in and sign-up use the same allowlisted PKCE OAuth seam',
      () async {
        final client = _FakeAuthClient();
        final repository = _repository(client);
        client.onLaunch = () => client.emit(
          MemberSessionEvent.signedIn,
          _session(authenticatedAt: _now),
        );

        final signIn = await repository.authenticate(
          const MemberAuthIntent.signIn(),
        );
        final signUp = await repository.authenticate(
          const MemberAuthIntent.signUp(),
        );

        expect(signIn.userId, _userId);
        expect(signUp.sessionId, _sessionId);
        expect(client.launches, hasLength(2));
        for (final launch in client.launches) {
          expect(launch.provider, MemberAuthProvider.google);
          expect(
            launch.redirectTo,
            Uri.parse('https://just-build-this.app/mobile/argus-auth/callback'),
          );
          expect(launch.scopes, 'openid email profile');
          expect(launch.queryParameters, isEmpty);
        }
        expect(
          repository.memberClientExpectation.issuer,
          'https://project.supabase.co/auth/v1',
        );
        expect(repository.memberClientExpectation.audience, 'authenticated');
      },
    );

    test('cancelled hosted auth does not retain a callback listener', () async {
      final client = _FakeAuthClient(launchResult: false);

      await expectLater(
        _repository(client).authenticate(const MemberAuthIntent.signIn()),
        throwsA(isA<MemberAuthCancelled>()),
      );

      expect(client.hasEventListener, isFalse);
    });

    test(
      'recent auth requests a Google account prompt and proves fresh AMR',
      () async {
        final client = _FakeAuthClient(
          current: _session(
            authenticatedAt: _now.subtract(const Duration(hours: 2)),
          ),
        );
        final repository = _repository(client);
        client.onLaunch = () => client.emit(
          MemberSessionEvent.signedIn,
          _session(sessionId: _newSessionId, authenticatedAt: _now),
        );

        final result = await repository.authenticate(
          const MemberAuthIntent.recentAuth(maxAge: Duration(minutes: 5)),
        );

        expect(result.userId, _userId);
        expect(result.sessionId, _newSessionId);
        expect(
          client.launches.single.queryParameters['prompt'],
          'select_account',
        );
        expect(client.launches.single.queryParameters['max_age'], '300');
        expect(
          client.launches.single.queryParameters['claims'],
          contains('auth_time'),
        );
      },
    );

    test('recent auth rejects a different returned Supabase user', () async {
      final client = _FakeAuthClient(current: _session(authenticatedAt: _now));
      final repository = _repository(client);
      client.onLaunch = () => client.emit(
        MemberSessionEvent.signedIn,
        _session(userId: _otherUserId, authenticatedAt: _now),
      );

      await expectLater(
        repository.authenticate(
          const MemberAuthIntent.recentAuth(maxAge: Duration(minutes: 5)),
        ),
        throwsA(isA<MemberAccountMismatch>()),
      );
    });

    test(
      'Apple recent auth fails closed because freshness is not provable',
      () async {
        final client = _FakeAuthClient(
          current: _session(authenticatedAt: _now),
        );
        final repository = _repository(
          client,
          provider: MemberAuthProvider.apple,
        );

        await expectLater(
          repository.authenticate(
            const MemberAuthIntent.recentAuth(maxAge: Duration(minutes: 5)),
          ),
          throwsA(
            isA<MemberAuthUnavailable>().having(
              (error) => error.reason,
              'reason',
              'recent_auth_not_supported_by_provider',
            ),
          ),
        );
        expect(client.launches, isEmpty);
      },
    );

    test(
      'restore refreshes an expired or near-expiry stored session first',
      () async {
        final client = _FakeAuthClient(
          current: _session(
            expiresAt: _now.add(const Duration(seconds: 30)),
            authenticatedAt: _now.subtract(const Duration(days: 1)),
          ),
          refreshed: _session(
            sessionId: _newSessionId,
            expiresAt: _now.add(const Duration(hours: 1)),
            authenticatedAt: _now.subtract(const Duration(days: 1)),
          ),
        );

        final result = await _repository(client).recover();

        expect(client.refreshCalls, 1);
        expect(result?.sessionId, _newSessionId);
      },
    );

    test(
      'offline refresh is surfaced instead of bootstrapping expired auth',
      () async {
        final client = _FakeAuthClient(
          current: _session(
            expiresAt: _now.subtract(const Duration(seconds: 1)),
          ),
          refreshError: StateError('offline'),
        );

        await expectLater(_repository(client).recover(), throwsStateError);
        expect(client.refreshCalls, 1);
      },
    );

    test('local and global logout scopes are always explicit', () async {
      final client = _FakeAuthClient();
      final repository = _repository(client);

      await repository.logout();
      await repository.logoutWithScope(MemberLogoutScope.global);

      expect(client.logoutScopes, [
        MemberLogoutScope.local,
        MemberLogoutScope.global,
      ]);
    });

    test(
      'malformed, wrong-issuer, and wrong-audience sessions fail closed',
      () async {
        for (final session in [
          const MemberSupabaseSession(accessToken: 'bad', userId: _userId),
          _session(issuer: 'https://attacker.example/auth/v1'),
          _session(audience: 'service_role'),
        ]) {
          final repository = _repository(_FakeAuthClient(current: session));
          await expectLater(
            repository.recover(),
            throwsA(isA<MemberAuthUnavailable>()),
          );
        }
      },
    );
  });

  group('native link policy', () {
    final policy = _links();

    test('accepts only exact Argus PKCE or error callbacks', () {
      expect(
        policy.acceptsArgusAuthCallback(
          Uri.parse(
            'https://just-build-this.app/mobile/argus-auth/callback?code=abcdefgh',
          ),
        ),
        isTrue,
      );
      expect(
        policy.acceptsArgusAuthCallback(
          Uri.parse(
            'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback?error=cancelled',
          ),
        ),
        isTrue,
      );
    });

    test('Webull completion is never consumed by Supabase Auth', () {
      final webull = Uri.parse(
        'https://just-build-this.app/mobile/webull/complete?completion=abcdefghijklmnop',
      );
      expect(policy.acceptsWebullCompletion(webull), isTrue);
      expect(policy.acceptsArgusAuthCallback(webull), isFalse);
      expect(policy.classify(webull), MemberNativeLinkKind.webullCompletion);
    });

    test('rejects duplicates, fragments, alternate targets, and return URLs', () {
      final rejected = [
        'https://just-build-this.app/mobile/argus-auth/callback?code=abcdefgh&code=ijklmnop',
        'https://just-build-this.app/mobile/argus-auth/callback?code=abcdefgh#access_token=secret',
        'http://just-build-this.app/mobile/argus-auth/callback?code=abcdefgh',
        'https://just-build-this.app:444/mobile/argus-auth/callback?code=abcdefgh',
        'https://evil.example/mobile/argus-auth/callback?code=abcdefgh',
        'https://just-build-this.app/mobile/argus-auth/callback/?code=abcdefgh',
        'https://just-build-this.app/mobile/argus-auth/callback?code=abcdefgh&redirect=https%3A%2F%2Fevil.example',
        'https://just-build-this.app/mobile/webull/complete?completion=abcdefghijklmnop&completion=qrstuvwxyzabcdef',
      ];
      for (final raw in rejected) {
        expect(policy.classify(Uri.parse(raw)), isNull, reason: raw);
      }
    });

    test('configuration rejects swapped custom schemes and custom ports', () {
      expect(
        () => MemberNativeLinkPolicy.parse(
          argusAuthAllowlist:
              'https://just-build-this.app/mobile/argus-auth/callback,'
              'com.ritualinvesting.ritual-investing-app.webull://argus-auth/callback',
          webullCompletionAllowlist:
              'https://just-build-this.app/mobile/webull/complete,'
              'com.ritualinvesting.ritual-investing-app.auth://webull/complete',
        ),
        throwsFormatException,
      );
      expect(
        () => MemberNativeLinkPolicy.parse(
          argusAuthAllowlist:
              'https://just-build-this.app/mobile/argus-auth/callback,'
              'com.ritualinvesting.ritual-investing-app.auth://argus-auth:444/callback',
          webullCompletionAllowlist:
              'https://just-build-this.app/mobile/webull/complete',
        ),
        throwsFormatException,
      );
    });
  });

  group('secure Supabase storage', () {
    test('session persistence strips provider OAuth credentials', () async {
      final driver = _MemorySecureStorage();
      final storage = SecureSupabaseLocalStorage(driver);
      await storage.persistSession(
        jsonEncode({
          'access_token': 'member-access',
          'refresh_token': 'member-refresh',
          'provider_token': 'must-not-persist',
          'provider_refresh_token': 'must-not-persist',
          'user': {'id': _userId},
        }),
      );

      final persisted = await storage.accessToken();
      expect(persisted, contains('member-access'));
      expect(persisted, isNot(contains('must-not-persist')));
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('PKCE verifier storage is namespaced and removable', () async {
      final driver = _MemorySecureStorage();
      final storage = SecureSupabasePkceStorage(driver);

      await storage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'verifier',
      );
      expect(
        await storage.getItem(key: 'supabase.auth.token-code-verifier'),
        'verifier',
      );
      expect(driver.values.keys.single, startsWith('supabase-member-pkce-v1:'));
      await storage.removeItem(key: 'supabase.auth.token-code-verifier');
      expect(driver.values, isEmpty);
    });
  });

  group('step-up receipt contract', () {
    test(
      'generated API receipt is action, user, session, and expiry bound',
      () async {
        final repository = ApiStepUpReceiptRepository(
          issue: (action) async => <String, Object?>{
            'receipt': 'server-issued-receipt-token',
            'action': 'webull_disconnect',
            'user_id': _userId,
            'session_id': _sessionId,
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 2))
                .toIso8601String(),
          },
        );
        final authorization = await repository.issue(
          action: SensitiveMemberAction.webullDisconnect,
          session: const AuthSession(
            accessToken: 'access',
            userId: _userId,
            sessionId: _sessionId,
          ),
        );
        expect(authorization.action, SensitiveMemberAction.webullDisconnect);
        expect(authorization.userId, _userId);
        expect(authorization.sessionId, _sessionId);
      },
    );

    test('generated API receipt rejects an intercepted session', () async {
      final repository = ApiStepUpReceiptRepository(
        issue: (action) async => <String, Object?>{
          'receipt': 'server-issued-receipt-token',
          'action': 'argus_delete',
          'user_id': _userId,
          'session_id': '018f3c2a-4b67-7a89-8abc-123456789099',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 2))
              .toIso8601String(),
        },
      );
      await expectLater(
        repository.issue(
          action: SensitiveMemberAction.argusDelete,
          session: const AuthSession(
            accessToken: 'access',
            userId: _userId,
            sessionId: _sessionId,
          ),
        ),
        throwsA(isA<InvalidStepUpReceipt>()),
      );
    });

    test('unwired server issuance fails closed', () async {
      const repository = UnavailableStepUpReceiptRepository();
      await expectLater(
        repository.issue(
          action: SensitiveMemberAction.argusDelete,
          session: const AuthSession(
            accessToken: 'access',
            userId: _userId,
            sessionId: _sessionId,
          ),
        ),
        throwsA(isA<StepUpUnavailable>()),
      );
    });

    test(
      'receipt is action/session bound, expiring, and one use in memory',
      () {
        final authorization = SensitiveActionAuthorization(
          receiptToken: 'server-issued-receipt',
          action: SensitiveMemberAction.webullDisconnect,
          userId: _userId,
          sessionId: _sessionId,
          expiresAt: _now.add(const Duration(minutes: 2)),
        );
        const session = AuthSession(
          accessToken: 'access',
          userId: _userId,
          sessionId: _sessionId,
        );

        expect(
          authorization.consumeFor(
            action: SensitiveMemberAction.webullDisconnect,
            session: session,
            now: _now,
          ),
          'server-issued-receipt',
        );
        expect(
          () => authorization.consumeFor(
            action: SensitiveMemberAction.webullDisconnect,
            session: session,
            now: _now,
          ),
          throwsA(isA<InvalidStepUpReceipt>()),
        );
      },
    );

    test('receipt rejects the wrong action before it can be consumed', () {
      final authorization = SensitiveActionAuthorization(
        receiptToken: 'server-issued-receipt',
        action: SensitiveMemberAction.webullDisconnect,
        userId: _userId,
        sessionId: _sessionId,
        expiresAt: _now.add(const Duration(minutes: 2)),
      );

      expect(
        () => authorization.consumeFor(
          action: SensitiveMemberAction.argusDelete,
          session: const AuthSession(
            accessToken: 'access',
            userId: _userId,
            sessionId: _sessionId,
          ),
          now: _now,
        ),
        throwsA(isA<InvalidStepUpReceipt>()),
      );
    });

    test('receipt rejects a different Supabase session', () {
      final authorization = SensitiveActionAuthorization(
        receiptToken: 'server-issued-receipt',
        action: SensitiveMemberAction.argusDelete,
        userId: _userId,
        sessionId: _sessionId,
        expiresAt: _now.add(const Duration(minutes: 2)),
      );

      expect(
        () => authorization.consumeFor(
          action: SensitiveMemberAction.argusDelete,
          session: const AuthSession(
            accessToken: 'access',
            userId: _userId,
            sessionId: _newSessionId,
          ),
          now: _now,
        ),
        throwsA(isA<InvalidStepUpReceipt>()),
      );
    });

    test('receipt rejects use at or after its expiry', () {
      final authorization = SensitiveActionAuthorization(
        receiptToken: 'server-issued-receipt',
        action: SensitiveMemberAction.argusDelete,
        userId: _userId,
        sessionId: _sessionId,
        expiresAt: _now,
      );

      expect(
        () => authorization.consumeFor(
          action: SensitiveMemberAction.argusDelete,
          session: const AuthSession(
            accessToken: 'access',
            userId: _userId,
            sessionId: _sessionId,
          ),
          now: _now,
        ),
        throwsA(isA<InvalidStepUpReceipt>()),
      );
    });
  });
}

SupabaseSessionRepository _repository(
  _FakeAuthClient client, {
  MemberAuthProvider provider = MemberAuthProvider.google,
}) => SupabaseSessionRepository(
  client: client,
  provider: provider,
  nativeLinks: _links(),
  supabaseUrl: Uri.parse('https://project.supabase.co'),
  now: () => _now,
  oauthCompletionTimeout: const Duration(seconds: 1),
);

MemberNativeLinkPolicy _links() => MemberNativeLinkPolicy.parse(
  argusAuthAllowlist:
      'https://just-build-this.app/mobile/argus-auth/callback,'
      'com.ritualinvesting.ritual-investing-app.auth://argus-auth/callback',
  webullCompletionAllowlist:
      'https://just-build-this.app/mobile/webull/complete,'
      'com.ritualinvesting.ritual-investing-app.webull://webull/complete',
);

MemberSupabaseSession _session({
  String userId = _userId,
  String sessionId = _sessionId,
  String issuer = 'https://project.supabase.co/auth/v1',
  String audience = 'authenticated',
  DateTime? expiresAt,
  DateTime? authenticatedAt,
}) {
  final payload = <String, Object?>{
    'sub': userId,
    'session_id': sessionId,
    'iss': issuer,
    'aud': audience,
    'exp':
        (expiresAt ?? _now.add(const Duration(hours: 1)))
            .millisecondsSinceEpoch ~/
        1000,
    if (authenticatedAt != null)
      'amr': [
        {
          'method': 'oauth',
          'timestamp': authenticatedAt.millisecondsSinceEpoch ~/ 1000,
        },
      ],
  };
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return MemberSupabaseSession(
    accessToken:
        '${part({'alg': 'RS256', 'typ': 'JWT'})}.${part(payload)}.signature',
    userId: userId,
  );
}

class _OAuthLaunch {
  const _OAuthLaunch({
    required this.provider,
    required this.redirectTo,
    required this.scopes,
    required this.queryParameters,
  });
  final MemberAuthProvider provider;
  final Uri redirectTo;
  final String scopes;
  final Map<String, String> queryParameters;
}

class _FakeAuthClient implements MemberSupabaseAuthClient {
  _FakeAuthClient({
    this.current,
    this.refreshed,
    this.refreshError,
    this.launchResult = true,
  });

  final StreamController<MemberSupabaseAuthChange> _events =
      StreamController.broadcast(sync: true);
  MemberSupabaseSession? current;
  MemberSupabaseSession? refreshed;
  Object? refreshError;
  bool launchResult;
  void Function()? onLaunch;
  final List<_OAuthLaunch> launches = [];
  final List<MemberLogoutScope> logoutScopes = [];
  int refreshCalls = 0;

  @override
  Stream<MemberSupabaseAuthChange> get events => _events.stream;

  bool get hasEventListener => _events.hasListener;

  void emit(MemberSessionEvent event, MemberSupabaseSession? session) {
    current = session;
    _events.add(MemberSupabaseAuthChange(event: event, session: session));
  }

  @override
  Future<MemberSupabaseSession?> getCurrentSession() async => current;

  @override
  Future<MemberSupabaseSession> refreshCurrentSession() async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
    return refreshed ?? (throw StateError('No refresh result.'));
  }

  @override
  Future<bool> launchOAuth({
    required MemberAuthProvider provider,
    required Uri redirectTo,
    required String scopes,
    required Map<String, String> queryParameters,
  }) async {
    launches.add(
      _OAuthLaunch(
        provider: provider,
        redirectTo: redirectTo,
        scopes: scopes,
        queryParameters: queryParameters,
      ),
    );
    onLaunch?.call();
    return launchResult;
  }

  @override
  Future<void> signOut(MemberLogoutScope scope) async {
    logoutScopes.add(scope);
    current = null;
  }
}

class _MemorySecureStorage implements MemberAuthSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
