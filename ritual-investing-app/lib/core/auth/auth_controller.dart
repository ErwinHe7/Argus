// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import 'auth0_session_repository.dart';

enum AuthPhase { signedOut, loading, signedIn, failure }

@immutable
class AuthState {
  const AuthState({required this.phase, this.message});
  final AuthPhase phase;
  final String? message;
}

class AuthController extends ChangeNotifier implements AccessTokenProvider {
  AuthController({required SessionRepository repository})
    : _repository = repository;
  final SessionRepository _repository;
  AuthState _state = const AuthState(phase: AuthPhase.signedOut);
  AuthState get state => _state;
  Future<void> restore() => _run(_repository.credentials);
  Future<void> login() => _run(() async => _repository.login());
  Future<void> _run(Future<AuthSession?> Function() action) async {
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final s = await action();
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

  Future<void> logout() async {
    await _repository.logout();
    _set(const AuthState(phase: AuthPhase.signedOut));
  }

  void markBootstrapFailure() {
    _set(
      const AuthState(
        phase: AuthPhase.failure,
        message: 'Your account could not be prepared. Please try again.',
      ),
    );
  }

  void _set(AuthState value) {
    _state = value;
    notifyListeners();
  }

  @override
  Future<String?> accessToken() async {
    final s = await _repository.credentials();
    if (s != null && _state.phase != AuthPhase.signedIn) {
      _set(const AuthState(phase: AuthPhase.signedIn));
    }
    return s?.accessToken;
  }
}
