// ignore_for_file: prefer_initializing_formals

import 'package:auth0_flutter/auth0_flutter.dart';

import 'member_auth.dart';

class Auth0SessionRepository implements SessionRepository {
  Auth0SessionRepository({
    required Auth0 auth0,
    required String audience,
    required String memberClientId,
    bool useHttpsCallbacks = true,
  }) : _auth0 = auth0,
       _audience = audience,
       _useHttpsCallbacks = useHttpsCallbacks,
       memberClientExpectation = MemberClientExpectation(
         authorizedParty: memberClientId,
       );

  factory Auth0SessionRepository.production({
    required String domain,
    required String memberClientId,
    required String audience,
    required bool useHttpsCallbacks,
  }) => Auth0SessionRepository(
    auth0: Auth0(domain, memberClientId),
    audience: audience,
    memberClientId: memberClientId,
    useHttpsCallbacks: useHttpsCallbacks,
  );

  final Auth0 _auth0;
  final String _audience;
  final bool _useHttpsCallbacks;

  WebAuthentication get _webAuthentication =>
      _auth0.webAuthentication(scheme: _useHttpsCallbacks ? 'https' : null);

  @override
  final MemberClientExpectation memberClientExpectation;

  @override
  Stream<AuthSession> get recoveredSessions => _webAuthentication
      .onCredentialsRecovered
      .map((credentials) => AuthSession(accessToken: credentials.accessToken));

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    final parameters = switch (intent.kind) {
      MemberAuthIntentKind.signIn => const <String, String>{},
      MemberAuthIntentKind.signUp => const {
        'screen_hint': 'signup',
        'prompt': 'login',
      },
      MemberAuthIntentKind.recentAuth => {
        'max_age': intent.maxAge!.inSeconds.toString(),
      },
    };
    final value = await _webAuthentication.login(
      audience: _audience,
      scopes: const {
        'openid',
        'profile',
        'offline_access',
        'read:self',
        'write:self',
        'simulate:self',
        'privacy:self',
      },
      parameters: parameters,
      useHTTPS: _useHttpsCallbacks,
    );
    return AuthSession(accessToken: value.accessToken);
  }

  @override
  Future<AuthSession?> recover() async {
    if (!await _auth0.credentialsManager.hasValidCredentials(minTtl: 60)) {
      return null;
    }
    final value = await _auth0.credentialsManager.credentials(minTtl: 60);
    return AuthSession(accessToken: value.accessToken);
  }

  @override
  Future<void> logout() async {
    try {
      await _webAuthentication.logout(useHTTPS: _useHttpsCallbacks);
    } catch (_) {
      await _auth0.credentialsManager.clearCredentials();
      rethrow;
    }
  }
}
