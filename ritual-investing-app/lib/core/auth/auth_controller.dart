// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import 'member_auth.dart';
import 'member_step_up.dart';

enum AuthPhase { signedOut, loading, signedIn, failure }

enum MemberAuthResult { authenticated, cancelled, unavailable }

@immutable
class AuthState {
  const AuthState({
    required this.phase,
    this.message,
    this.canLogout = false,
    this.isPasswordRecovery = false,
  });
  final AuthPhase phase;
  final String? message;
  final bool canLogout;
  final bool isPasswordRecovery;
}

class AuthController extends ChangeNotifier implements AccessTokenProvider {
  AuthController({
    required SessionRepository repository,
    StepUpReceiptRepository stepUpReceipts =
        const UnavailableStepUpReceiptRepository(),
  }) : _repository = repository,
       _stepUpReceipts = stepUpReceipts {
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
  }
  final SessionRepository _repository;
  final StepUpReceiptRepository _stepUpReceipts;
  late final StreamSubscription<MemberSessionChange> _recoverySubscription;
  final StreamController<void> _recoveries = StreamController.broadcast(
    sync: true,
  );
  int _recoveryVersion = 0;
  AuthSession? _activeSession;
  AuthState _state = const AuthState(phase: AuthPhase.signedOut);
  AuthState get state => _state;
  AuthSession? get activeSession => _activeSession;
  MemberClientExpectation get memberClientExpectation =>
      _repository.memberClientExpectation;
  Stream<void> get recoveredSessions => _recoveries.stream;
  Future<void> restore() => _run(_repository.recover);
  Future<MemberAuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final PasswordSessionRepository repository;
    if (_repository case final PasswordSessionRepository supported) {
      repository = supported;
    } else {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Sign-in is temporarily unavailable.',
        ),
      );
      return MemberAuthResult.unavailable;
    }
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final session = await repository.signInWithPassword(
        email: email,
        password: password,
      );
      _adoptSession(session);
      return MemberAuthResult.authenticated;
    } on MemberAuthCancelled {
      _set(const AuthState(phase: AuthPhase.signedOut));
      return MemberAuthResult.cancelled;
    } on MemberAuthUnavailable catch (error) {
      _set(
        AuthState(
          phase: AuthPhase.failure,
          message: _passwordSignInMessage(error.reason),
        ),
      );
      return MemberAuthResult.unavailable;
    } on Object {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Sign-in is temporarily unavailable.',
        ),
      );
      return MemberAuthResult.unavailable;
    }
  }

  Future<MemberAuthResult> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final PasswordSessionRepository repository;
    if (_repository case final PasswordSessionRepository supported) {
      repository = supported;
    } else {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Account creation is temporarily unavailable.',
        ),
      );
      return MemberAuthResult.unavailable;
    }
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final session = await repository.signUpWithPassword(
        email: email,
        password: password,
      );
      _adoptSession(session);
      return MemberAuthResult.authenticated;
    } on MemberAuthCancelled {
      _set(const AuthState(phase: AuthPhase.signedOut));
      return MemberAuthResult.cancelled;
    } on MemberAuthUnavailable catch (error) {
      _set(
        AuthState(
          phase: AuthPhase.failure,
          message: _passwordSignUpMessage(error.reason),
        ),
      );
      return MemberAuthResult.unavailable;
    } on Object {
      _set(
        const AuthState(
          phase: AuthPhase.failure,
          message: 'Account creation is temporarily unavailable.',
        ),
      );
      return MemberAuthResult.unavailable;
    }
  }

  Future<void> requestPasswordRecovery(String email) async {
    if (_repository case final PasswordRecoverySessionRepository supported) {
      try {
        await supported.requestPasswordRecovery(email: email);
      } on Object {
        // Always return the same result to avoid disclosing account existence.
      }
    }
  }

  Future<bool> updatePassword(String password) async {
    if (_repository case final PasswordRecoverySessionRepository supported) {
      try {
        await supported.updatePassword(password: password);
        final session = _activeSession;
        if (session != null) _adoptSession(session);
        return true;
      } on Object {
        return false;
      }
    }
    return false;
  }

  static String _passwordSignInMessage(String reason) => switch (reason) {
    'invalid_credentials' ||
    'user_not_found' => 'Email or password is incorrect.',
    'email_not_confirmed' => 'Confirm your email before signing in.',
    'email_provider_disabled' => 'Email sign-in is not enabled for this beta.',
    'user_banned' => 'This account cannot sign in.',
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' ||
    'over_sms_send_rate_limit' => 'Too many sign-in attempts. Try again later.',
    _ => 'Sign-in is temporarily unavailable.',
  };

  static String _passwordSignUpMessage(String reason) => switch (reason) {
    'email_confirmation_required' =>
      'Check your email to confirm your account, then sign in.',
    'email_exists' ||
    'user_already_exists' => 'An account already exists for this email.',
    'weak_password' => 'Choose a stronger password and try again.',
    'email_provider_disabled' => 'Email account creation is not enabled.',
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => 'Too many attempts. Try again later.',
    _ => 'Account creation is temporarily unavailable.',
  };

  Future<AuthSession> reauthenticate(Duration maxAge) async {
    final session = _activeSession ?? await _repository.recover();
    if (session == null) {
      throw const MemberAuthUnavailable('password_credentials_required');
    }
    final authenticatedAt = session.authenticatedAt;
    final now = DateTime.now().toUtc();
    if (authenticatedAt == null ||
        authenticatedAt.isAfter(now.add(const Duration(seconds: 30))) ||
        now.difference(authenticatedAt) > maxAge) {
      throw const MemberAuthUnavailable('password_credentials_required');
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
            // A callback for a different user is rejected without becoming an
            // unhandled auth-stream exception.
          }
        }
      case MemberSessionEvent.passwordRecovery:
        final session = change.session;
        if (session != null) {
          _recoveryVersion++;
          try {
            _adoptSession(session, isPasswordRecovery: true);
            _recoveries.add(null);
          } on MemberAccountMismatch {
            // Keep the existing app identity bound until an explicit logout.
          }
        }
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

  void _adoptSession(AuthSession session, {bool isPasswordRecovery = false}) {
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
    _set(
      AuthState(
        phase: AuthPhase.signedIn,
        isPasswordRecovery: isPasswordRecovery,
      ),
    );
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
    unawaited(_recoveries.close());
    super.dispose();
  }
}
