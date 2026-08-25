import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth0_session_repository.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('auth0.com/auth0_flutter/web_auth');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('login requests the complete member API scope set', () async {
    MethodCall? loginCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          loginCall = call;
          return <String, Object?>{
            'idToken': 'id-token',
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresAt': '2099-01-01T00:00:00.000Z',
            'scopes': <String>[],
            'userProfile': <String, Object?>{'sub': 'auth0|member'},
            'tokenType': 'Bearer',
          };
        });
    final repository = Auth0SessionRepository(
      auth0: Auth0(
        'tenant.auth0.com',
        'mobile-client',
        credentialsManager: _TrackingCredentialsManager(),
      ),
      audience: 'https://api.example.com',
      memberClientId: 'mobile-client',
    );

    final session = await repository.authenticate(
      const MemberAuthIntent.signIn(),
    );

    expect(session.accessToken, 'access-token');
    expect(loginCall?.method, 'webAuth#login');
    final arguments = Map<String, Object?>.from(
      loginCall?.arguments as Map<dynamic, dynamic>,
    );
    expect(arguments['audience'], 'https://api.example.com');
    expect(Set<String>.from(arguments['scopes']! as List<dynamic>), {
      'openid',
      'profile',
      'offline_access',
      'read:self',
      'write:self',
      'simulate:self',
      'privacy:self',
    });
    expect(arguments['parameters'], isEmpty);
    expect(arguments['scheme'], 'https');
    expect(arguments['useHTTPS'], isTrue);
    expect(repository.memberClientExpectation.authorizedParty, 'mobile-client');
  });

  test(
    'sign-up and recent-auth map to distinct exact SDK parameters',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return <String, Object?>{
              'idToken': 'id-token',
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresAt': '2099-01-01T00:00:00.000Z',
              'scopes': <String>[],
              'userProfile': <String, Object?>{'sub': 'auth0|member'},
              'tokenType': 'Bearer',
            };
          });
      final repository = Auth0SessionRepository(
        auth0: Auth0(
          'tenant.auth0.com',
          'mobile-client',
          credentialsManager: _TrackingCredentialsManager(),
        ),
        audience: 'https://api.example.com',
        memberClientId: 'mobile-client',
      );

      await repository.authenticate(const MemberAuthIntent.signUp());
      await repository.authenticate(
        const MemberAuthIntent.recentAuth(maxAge: Duration(minutes: 5)),
      );

      final signup = Map<String, Object?>.from(
        calls[0].arguments as Map<dynamic, dynamic>,
      );
      final recent = Map<String, Object?>.from(
        calls[1].arguments as Map<dynamic, dynamic>,
      );
      expect(signup['parameters'], {
        'screen_hint': 'signup',
        'prompt': 'login',
      });
      expect(recent['parameters'], {'max_age': '300'});
    },
  );

  test('logout clears local credentials when remote logout fails', () async {
    final credentialsManager = _TrackingCredentialsManager();
    MethodCall? logoutCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          logoutCall = call;
          throw PlatformException(code: 'network_error');
        });
    final repository = Auth0SessionRepository(
      auth0: Auth0(
        'tenant.auth0.com',
        'mobile-client',
        credentialsManager: credentialsManager,
      ),
      audience: 'https://api.example.com',
      memberClientId: 'mobile-client',
    );

    await expectLater(
      repository.logout(),
      throwsA(isA<WebAuthenticationException>()),
    );

    expect(credentialsManager.clearCalls, 1);
    expect(logoutCall?.method, 'webAuth#logout');
    expect(
      Map<String, Object?>.from(
        logoutCall?.arguments as Map<dynamic, dynamic>,
      )['scheme'],
      'https',
    );
  });

  test(
    'rollback mode keeps the SDK custom scheme for login and logout',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'webAuth#logout') return null;
            return <String, Object?>{
              'idToken': 'id-token',
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresAt': '2099-01-01T00:00:00.000Z',
              'scopes': <String>[],
              'userProfile': <String, Object?>{'sub': 'auth0|member'},
              'tokenType': 'Bearer',
            };
          });
      final repository = Auth0SessionRepository(
        auth0: Auth0(
          'tenant.auth0.com',
          'mobile-client',
          credentialsManager: _TrackingCredentialsManager(),
        ),
        audience: 'https://api.example.com',
        memberClientId: 'mobile-client',
        useHttpsCallbacks: false,
      );

      await repository.authenticate(const MemberAuthIntent.signIn());
      await repository.logout();

      for (final call in calls) {
        final arguments = Map<String, Object?>.from(
          call.arguments as Map<dynamic, dynamic>,
        );
        expect(arguments['scheme'], isNull);
        expect(arguments['useHTTPS'], isFalse);
      }
    },
  );
}

class _TrackingCredentialsManager implements CredentialsManager {
  int clearCalls = 0;

  @override
  Future<bool> clearCredentials() async {
    clearCalls++;
    return true;
  }

  @override
  Future<void> clearApiCredentials({required String audience, String? scope}) =>
      throw UnimplementedError();

  @override
  Future<Credentials> credentials({
    int minTtl = 0,
    Set<String> scopes = const {},
    Map<String, String> parameters = const {},
  }) => throw UnimplementedError();

  @override
  Future<ApiCredentials> getApiCredentials({
    required String audience,
    Set<String> scope = const {},
    int minTtl = 0,
    Map<String, String> parameters = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();

  @override
  Future<bool> hasValidCredentials({int minTtl = 0}) async => false;

  @override
  Future<Credentials> renewCredentials({
    Map<String, String> parameters = const {},
  }) => throw UnimplementedError();

  @override
  Future<SSOCredentials> ssoCredentials({
    Map<String, String> parameters = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();

  @override
  Future<bool> storeCredentials(Credentials credentials) async => true;

  @override
  Future<UserProfile?> user() async => null;
}
