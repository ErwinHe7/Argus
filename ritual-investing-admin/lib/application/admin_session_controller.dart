import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import '../data/admin_gateway.dart';
import '../domain/admin_models.dart';

enum AdminSessionPhase { loading, signedOut, ready, denied }

abstract interface class AdminCredentialRepository {
  Future<String?> restore();
  Future<String?> freshToken();
  Future<String> login();
  Future<void> logout();
}

class Auth0AdminCredentialRepository implements AdminCredentialRepository {
  Auth0AdminCredentialRepository(this._auth0, this._audience);
  final Auth0 _auth0;
  final String _audience;

  @override
  Future<String?> restore() async {
    if (!await _auth0.credentialsManager.hasValidCredentials(minTtl: 60)) {
      return null;
    }
    return (await _auth0.credentialsManager.credentials(minTtl: 60))
        .accessToken;
  }

  @override
  Future<String?> freshToken() async {
    if (!await _auth0.credentialsManager.hasValidCredentials(minTtl: 60)) {
      return null;
    }
    return (await _auth0.credentialsManager.credentials(minTtl: 60))
        .accessToken;
  }

  @override
  Future<String> login() async => (await _auth0.webAuthentication().login(
    audience: _audience,
    scopes: {'openid', 'profile', 'offline_access'},
  )).accessToken;
  @override
  Future<void> logout() => _auth0.webAuthentication().logout();
}

class AdminSessionController extends ChangeNotifier
    implements AccessTokenProvider {
  AdminSessionController._(this._credentials);
  factory AdminSessionController({
    required AdminCredentialRepository credentials,
  }) => AdminSessionController._(credentials);
  AdminSessionController.fixture({required Set<String> permissions})
    : _credentials = null,
      _phase = AdminSessionPhase.ready,
      _session = AdminStaffSession(
        staffId: 'fixture-staff',
        displayLabel: 'Fixture operator',
        permissions: permissions,
        revocationEpoch: 0,
      ),
      _token = 'fixture';

  final AdminCredentialRepository? _credentials;
  AdminGateway? _gateway;
  AdminSessionPhase _phase = AdminSessionPhase.loading;
  AdminStaffSession? _session;
  String? _token;
  void Function(String location)? onNavigate;

  AdminSessionPhase get phase => _phase;
  AdminStaffSession? get session => _session;
  bool get isReady => _phase == AdminSessionPhase.ready;
  bool permits(String permission) =>
      _session?.permissions.contains(permission) ?? false;

  void attachGateway(AdminGateway gateway) => _gateway = gateway;
  void goTo(String location) => onNavigate?.call(location);

  Future<void> restore() async {
    if (_credentials == null || isReady) return;
    await _authenticate(_credentials.restore);
  }

  Future<void> login() async {
    final credentials = _credentials;
    if (credentials == null) return;
    await _authenticate(() async => credentials.login());
  }

  Future<void> _authenticate(Future<String?> Function() action) async {
    _phase = AdminSessionPhase.loading;
    notifyListeners();
    try {
      _token = await action();
      if (_token == null) {
        _phase = AdminSessionPhase.signedOut;
      } else {
        _session = await _gateway!.loadSession();
        _phase = AdminSessionPhase.ready;
      }
    } catch (_) {
      _token = null;
      _session = null;
      _phase = AdminSessionPhase.denied;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _credentials?.logout();
    _token = null;
    _session = null;
    _phase = AdminSessionPhase.signedOut;
    notifyListeners();
  }

  void handleAuthorizationDenied(int statusCode) {
    _token = null;
    _session = null;
    _phase = statusCode == 401
        ? AdminSessionPhase.signedOut
        : AdminSessionPhase.denied;
    notifyListeners();
  }

  @override
  Future<String?> accessToken() async {
    final credentials = _credentials;
    if (credentials == null) return _token;
    if (_phase == AdminSessionPhase.denied) return null;
    try {
      final token = await credentials.freshToken();
      if (token == null) {
        _token = null;
        _session = null;
        _phase = AdminSessionPhase.signedOut;
        notifyListeners();
        return null;
      }
      _token = token;
      return token;
    } catch (_) {
      _token = null;
      _session = null;
      _phase = AdminSessionPhase.denied;
      notifyListeners();
      return null;
    }
  }
}
