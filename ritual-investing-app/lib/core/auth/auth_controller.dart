// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import 'member_auth.dart';

enum AuthPhase { signedOut, loading, signedIn, failure }

@immutable
class AuthState {
  const AuthState({required this.phase, this.message, this.canLogout = false});
  final AuthPhase phase;
  final String? message;
  final bool canLogout;
}

class AuthController extends ChangeNotifier implements AccessTokenProvider {
  AuthController({required SessionRepository repository})
    : _repository = repository {
    _recoverySubscription = _repository.recoveredSessions.listen(
      _acceptRecoveredSession,
    );
  }
  final SessionRepository _repository;
  late final StreamSubscription<AuthSession> _recoverySubscription;
  final StreamController<void> _recoveries = StreamController.broadcast(
    sync: true,
  );
  int _recoveryVersion = 0;
  AuthState _state = const AuthState(phase: AuthPhase.signedOut);
  AuthState get state => _state;
  MemberClientExpectation get memberClientExpectation =>
      _repository.memberClientExpectation;
  Stream<void> get recoveredSessions => _recoveries.stream;
  Future<void> restore() => _run(_repository.recover);
  Future<void> login() => signIn();
  Future<void> signIn() =>
      _run(() => _repository.authenticate(const MemberAuthIntent.signIn()));
  Future<void> signUp() =>
      _run(() => _repository.authenticate(const MemberAuthIntent.signUp()));
  Future<void> reauthenticate(Duration maxAge) async {
    await _repository.authenticate(MemberAuthIntent.recentAuth(maxAge: maxAge));
  }

  Future<void> _run(Future<AuthSession?> Function() action) async {
    final recoveryVersion = _recoveryVersion;
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final s = await action();
      if (s == null && recoveryVersion != _recoveryVersion) return;
      _set(
        s == null
            ? const AuthState(phase: AuthPhase.signedOut)
            : const AuthState(phase: AuthPhase.signedIn),
      );
    } catch (_) {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Sign-in is temporarily unavailable.',
        ),
      );
    }
  }

  void _acceptRecoveredSession(AuthSession session) {
    _recoveryVersion++;
    _set(const AuthState(phase: AuthPhase.signedIn));
    _recoveries.add(null);
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // A remote logout failure must not trap the user in an authenticated UI.
    }
    _set(const AuthState(phase: AuthPhase.signedOut));
  }

  void markBootstrapFailure() {
    _set(
      const AuthState(
        phase: AuthPhase.failure,
        message: 'Your account could not be prepared. Please try again.',
        canLogout: true,
      ),
    );
  }

  void _set(AuthState value) {
    _state = value;
    notifyListeners();
  }

  @override
  Future<String?> accessToken() async {
    final s = await _repository.recover();
    if (s != null && _state.phase != AuthPhase.signedIn) {
      _set(const AuthState(phase: AuthPhase.signedIn));
    }
    return s?.accessToken;
  }

  @override
  void dispose() {
    unawaited(_recoverySubscription.cancel());
    unawaited(_recoveries.close());
    super.dispose();
  }
}
