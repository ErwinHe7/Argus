import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_gateway.dart';
import '../domain/admin_models.dart';

enum AdminSessionPhase { loading, signedOut, requiresAal2, ready, denied }

enum AdminAssuranceLevel { aal1, aal2 }

@visibleForTesting
String selectSingleVerifiedTotpFactor({
  required List<String> verifiedFactorIds,
  required List<String> verifiedTotpFactorIds,
}) {
  if (verifiedFactorIds.length != 1 ||
      verifiedTotpFactorIds.length != 1 ||
      verifiedFactorIds.single != verifiedTotpFactorIds.single) {
    throw StateError('exactly_one_verified_totp_factor_required');
  }
  return verifiedTotpFactorIds.single;
}

@immutable
class AdminCredentialSnapshot {
  const AdminCredentialSnapshot({
    required this.accessToken,
    required this.assuranceLevel,
  });
  final String accessToken;
  final AdminAssuranceLevel assuranceLevel;
}

abstract interface class AdminCredentialRepository {
  Future<AdminCredentialSnapshot?> restore();
  Future<AdminCredentialSnapshot?> freshCredential();
  Future<AdminCredentialSnapshot?> login();
  Future<AdminCredentialSnapshot?> verifySecondFactor(String code);
  Future<void> logout({required bool global});
}

class SupabaseAdminCredentialRepository implements AdminCredentialRepository {
  SupabaseAdminCredentialRepository(this._client, this._redirectTo);
  final SupabaseClient _client;
  final Uri _redirectTo;

  Future<AdminCredentialSnapshot?> _snapshot(Session? session) async {
    if (session == null) return null;
    final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return AdminCredentialSnapshot(
      accessToken: session.accessToken,
      assuranceLevel:
          assurance.currentLevel == AuthenticatorAssuranceLevels.aal2
          ? AdminAssuranceLevel.aal2
          : AdminAssuranceLevel.aal1,
    );
  }

  @override
  Future<AdminCredentialSnapshot?> restore() =>
      _snapshot(_client.auth.currentSession);

  @override
  Future<AdminCredentialSnapshot?> freshCredential() async =>
      _snapshot((await _client.auth.refreshSession()).session);

  @override
  Future<AdminCredentialSnapshot?> login() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectTo.toString(),
      authScreenLaunchMode: LaunchMode.platformDefault,
    );
    return _snapshot(_client.auth.currentSession);
  }

  @override
  Future<AdminCredentialSnapshot?> verifySecondFactor(String code) async {
    final factors = await _client.auth.mfa.listFactors();
    final verified = factors.all
        .where((factor) => factor.status == FactorStatus.verified)
        .toList(growable: false);
    final factorId = selectSingleVerifiedTotpFactor(
      verifiedFactorIds: verified.map((factor) => factor.id).toList(),
      verifiedTotpFactorIds: factors.totp.map((factor) => factor.id).toList(),
    );
    await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
    return _snapshot(_client.auth.currentSession);
  }

  @override
  Future<void> logout({required bool global}) => _client.auth.signOut(
    scope: global ? SignOutScope.global : SignOutScope.local,
  );
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
    await _authenticate(credentials.login);
  }

  Future<void> verifySecondFactor(String code) async {
    final credentials = _credentials;
    if (credentials == null ||
        _phase != AdminSessionPhase.requiresAal2 ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      return;
    }
    await _authenticate(() => credentials.verifySecondFactor(code));
  }

  Future<void> _authenticate(
    Future<AdminCredentialSnapshot?> Function() action,
  ) async {
    _phase = AdminSessionPhase.loading;
    _clearSensitiveState();
    notifyListeners();
    try {
      final credential = await action();
      if (credential == null) {
        _phase = AdminSessionPhase.signedOut;
      } else if (credential.assuranceLevel != AdminAssuranceLevel.aal2) {
        _phase = AdminSessionPhase.requiresAal2;
      } else {
        _token = credential.accessToken;
        _session = await _gateway!.loadSession();
        _phase = AdminSessionPhase.ready;
      }
    } catch (_) {
      _clearSensitiveState();
      _phase = AdminSessionPhase.denied;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _credentials?.logout(global: true);
    _clearSensitiveState();
    _phase = AdminSessionPhase.signedOut;
    notifyListeners();
  }

  void handleAuthorizationDenied(int statusCode) {
    _clearSensitiveState();
    _phase = statusCode == 401
        ? AdminSessionPhase.signedOut
        : AdminSessionPhase.denied;
    notifyListeners();
  }

  void _clearSensitiveState() {
    _token = null;
    _session = null;
  }

  @override
  Future<String?> accessToken() async {
    final credentials = _credentials;
    if (credentials == null) return _token;
    if (_phase == AdminSessionPhase.denied ||
        _phase == AdminSessionPhase.requiresAal2) {
      return null;
    }
    try {
      final credential = await credentials.freshCredential();
      if (credential == null) {
        _clearSensitiveState();
        _phase = AdminSessionPhase.signedOut;
        notifyListeners();
        return null;
      }
      if (credential.assuranceLevel != AdminAssuranceLevel.aal2) {
        _clearSensitiveState();
        _phase = AdminSessionPhase.requiresAal2;
        notifyListeners();
        return null;
      }
      _token = credential.accessToken;
      return _token;
    } catch (_) {
      _clearSensitiveState();
      _phase = AdminSessionPhase.denied;
      notifyListeners();
      return null;
    }
  }
}
