// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import 'member_auth.dart';
import 'member_auth_signal_base.dart';
import 'member_step_up.dart';

enum AuthPhase { signedOut, loading, signedIn, failure }

enum MemberAuthResult { authenticated, started, cancelled, unavailable }

@immutable
class AuthState {
  const AuthState({required this.phase, this.message, this.canLogout = false});
  final AuthPhase phase;
  final String? message;
  final bool canLogout;
}

class AuthController extends ChangeNotifier implements AccessTokenProvider {
  AuthController({
    required SessionRepository repository,
    StepUpReceiptRepository stepUpReceipts =
        const UnavailableStepUpReceiptRepository(),
    MemberAuthSignal authSignal = const NoopMemberAuthSignal(),
  }) : _repository = repository,
       _stepUpReceipts = stepUpReceipts,
       _authSignal = authSignal {
    final source = repository is SessionChangeRepository
        ? (repository as SessionChangeRepository).sessionChanges
        : repository.recoveredSessions.map(
            (session) => MemberSessionChange(
              event: MemberSessionEvent.signedIn,
              session: session,
            ),
          );
    _recoverySubscription = source.listen(
      _acceptSessionChange,
      onError: _acceptSessionStreamError,
    );
    _logoutSignalSubscription = _authSignal.logoutEvents.listen((_) {
      unawaited(_acceptRemoteLogout());
    });
  }
  final SessionRepository _repository;
  final StepUpReceiptRepository _stepUpReceipts;
  final MemberAuthSignal _authSignal;
  late final StreamSubscription<MemberSessionChange> _recoverySubscription;
  late final StreamSubscription<void> _logoutSignalSubscription;
  final StreamController<void> _recoveries = StreamController.broadcast(
    sync: true,
  );
  final StreamController<void> _invalidations = StreamController.broadcast(
    sync: true,
  );
  bool _acceptingRemoteLogout = false;
  int _recoveryVersion = 0;
  AuthSession? _activeSession;
  AuthState _state = const AuthState(phase: AuthPhase.signedOut);
  AuthState get state => _state;
  AuthSession? get activeSession => _activeSession;
  MemberClientExpectation get memberClientExpectation =>
      _repository.memberClientExpectation;
  Stream<void> get recoveredSessions => _recoveries.stream;
  Stream<void> get invalidatedSessions => _invalidations.stream;
  Future<void> restore() => _run(_repository.recover);

  Future<MemberAuthResult> signInWithGoogle() async {
    final GoogleOAuthSessionRepository repository;
    if (_repository case final GoogleOAuthSessionRepository supported) {
      repository = supported;
    } else {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Google sign-in is temporarily unavailable.',
        ),
      );
      return MemberAuthResult.unavailable;
    }
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final session = await repository.signInWithGoogle();
      if (session != null) _adoptSession(session);
      if (_activeSession != null) return MemberAuthResult.authenticated;
      _set(const AuthState(phase: AuthPhase.signedOut));
      return MemberAuthResult.started;
    } on MemberAuthCancelled {
      _set(const AuthState(phase: AuthPhase.signedOut));
      return MemberAuthResult.cancelled;
    } on MemberAuthUnavailable catch (error) {
      _set(
        AuthState(
          phase: AuthPhase.failure,
          message: _googleSignInMessage(error.reason),
        ),
      );
      return MemberAuthResult.unavailable;
    } on Object {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Google sign-in is temporarily unavailable.',
        ),
      );
      return MemberAuthResult.unavailable;
    }
  }

  static String _googleSignInMessage(String reason) => switch (reason) {
    'provider_disabled' || 'oauth_provider_not_supported' =>
      'Google sign-in is not enabled for this app yet.',
    'user_banned' => 'This Google account cannot sign in.',
    'over_request_rate_limit' =>
      'Too many sign-in attempts. Please try again later.',
    _ => 'Google sign-in is temporarily unavailable.',
  };

  Future<AuthSession> reauthenticate(Duration maxAge) async {
    final session = _activeSession ?? await _repository.recover();
    if (session == null) {
      throw const MemberAuthUnavailable('recent_authentication_required');
    }
    final authenticatedAt = session.authenticatedAt;
    final now = DateTime.now().toUtc();
    if (authenticatedAt == null ||
        authenticatedAt.isAfter(now.add(const Duration(seconds: 30))) ||
        now.difference(authenticatedAt) > maxAge) {
      throw const MemberAuthUnavailable('recent_authentication_required');
    }
    if (_activeSession == null) _adoptSession(session);
    return session;
  }

  Future<SensitiveActionAuthorization> authorizeSensitiveAction(
    SensitiveMemberAction action, {
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final session = await reauthenticate(maxAge);
    if (session.userId == null || session.sessionId == null) {
      throw const StepUpUnavailable();
    }
    final receipt = await _stepUpReceipts.issue(
      action: action,
      session: session,
    );
    if (receipt.action != action ||
        receipt.userId != session.userId ||
        receipt.sessionId != session.sessionId) {
      throw const InvalidStepUpReceipt();
    }
    return receipt;
  }

  Future<void> _run(Future<AuthSession?> Function() action) async {
    final recoveryVersion = _recoveryVersion;
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final s = await action();
      if (s == null && recoveryVersion != _recoveryVersion) return;
      if (s == null) {
        _clearSession();
      } else {
        _adoptSession(s);
      }
    } catch (_) {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Sign-in is temporarily unavailable.',
        ),
      );
    }
  }

  void _acceptSessionChange(MemberSessionChange change) {
    switch (change.event) {
      case MemberSessionEvent.signedOut || MemberSessionEvent.userDeleted:
        _clearSession();
        if (!_acceptingRemoteLogout) _authSignal.publishLogout();
      case MemberSessionEvent.initialSession when change.session == null:
        if (_state.phase != AuthPhase.loading) _clearSession();
      case MemberSessionEvent.initialSession ||
          MemberSessionEvent.signedIn ||
          MemberSessionEvent.tokenRefreshed ||
          MemberSessionEvent.userUpdated ||
          MemberSessionEvent.mfaChallengeVerified:
        final session = change.session;
        if (session != null) {
          _recoveryVersion++;
          try {
            _adoptSession(session);
            _recoveries.add(null);
          } on MemberAccountMismatch {
            _clearSession();
            _authSignal.publishLogout();
          }
        }
      case MemberSessionEvent.passwordRecovery:
        // Password recovery is not an accepted member-auth lifecycle.
        _clearSession();
        _authSignal.publishLogout();
    }
  }

  void _acceptSessionStreamError(Object _, [StackTrace? stackTrace]) {
    _set(
      AuthState(
        phase: AuthPhase.failure,
        message: _activeSession == null
            ? 'Sign-in is temporarily unavailable.'
            : 'Your session could not be refreshed. Check your connection and retry.',
        canLogout: _activeSession != null,
      ),
    );
  }

  void _adoptSession(AuthSession session) {
    final currentUser = _activeSession?.userId;
    if (currentUser != null &&
        session.userId != null &&
        currentUser != session.userId) {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'The returned account did not match this app session.',
          canLogout: true,
        ),
      );
      throw const MemberAccountMismatch();
    }
    _activeSession = session;
    _set(const AuthState(phase: AuthPhase.signedIn));
  }

  void _clearSession() {
    _activeSession = null;
    _set(const AuthState(phase: AuthPhase.signedOut));
  }

  Future<void> logout() async {
    await logoutWithScope(MemberLogoutScope.local);
  }

  Future<void> logoutEverywhere() async {
    await logoutWithScope(MemberLogoutScope.global);
  }

  Future<void> logoutWithScope(MemberLogoutScope scope) async {
    try {
      if (_repository case final ScopedSessionLogout repository) {
        await repository.logoutWithScope(scope);
      } else {
        await _repository.logout();
      }
    } catch (_) {
      // A remote logout failure must not trap the user in an authenticated UI.
    }
    _clearSession();
    _authSignal.publishLogout();
  }

  Future<void> _acceptRemoteLogout() async {
    if (_acceptingRemoteLogout) return;
    _acceptingRemoteLogout = true;
    try {
      try {
        if (_repository case final ScopedSessionLogout repository) {
          await repository.logoutWithScope(MemberLogoutScope.local);
        } else {
          await _repository.logout();
        }
      } on Object {
        // The signal still invalidates local private UI if SDK cleanup fails.
      }
      _clearSession();
      _invalidations.add(null);
    } finally {
      _acceptingRemoteLogout = false;
    }
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
    if (s != null) {
      _adoptSession(s);
    }
    return s?.accessToken;
  }

  @override
  void dispose() {
    unawaited(_recoverySubscription.cancel());
    unawaited(_logoutSignalSubscription.cancel());
    unawaited(_recoveries.close());
    unawaited(_invalidations.close());
    _authSignal.close();
    super.dispose();
  }
}
