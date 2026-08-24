// ignore_for_file: prefer_initializing_formals

import 'package:auth0_flutter/auth0_flutter.dart';

class AuthSession {
  const AuthSession({required this.accessToken});
  final String accessToken;
}

abstract interface class SessionRepository {
  Future<AuthSession> login();
  Future<AuthSession?> credentials();
  Future<void> logout();
}

class Auth0SessionRepository implements SessionRepository {
  Auth0SessionRepository({required Auth0 auth0, required String audience})
    : _auth0 = auth0,
      _audience = audience;
  final Auth0 _auth0;
  final String _audience;
  @override
  Future<AuthSession> login() async {
    final value = await _auth0.webAuthentication().login(
      audience: _audience,
      scopes: {'openid', 'profile', 'offline_access'},
    );
    return AuthSession(accessToken: value.accessToken);
  }

  @override
  Future<AuthSession?> credentials() async {
    if (!await _auth0.credentialsManager.hasValidCredentials(minTtl: 60)) {
      return null;
    }
    final value = await _auth0.credentialsManager.credentials(minTtl: 60);
    return AuthSession(accessToken: value.accessToken);
  }

  @override
  Future<void> logout() => _auth0.webAuthentication().logout();
}
