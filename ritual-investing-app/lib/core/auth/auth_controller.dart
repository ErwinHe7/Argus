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
  Future<MemberAuthResult> login() => signIn();
  Future<MemberAuthResult> signIn() =>
      _authenticate(const MemberAuthIntent.signIn());
  Future<MemberAuthResult> signUp() =>
      _authenticate(const MemberAuthIntent.signUp());
  Future<AuthSession> reauthenticate(Duration maxAge) async {
    final expectedUser = _activeSession?.userId;
    final session = await _repository.authenticate(
      MemberAuthIntent.recentAuth(maxAge: maxAge),
    );
    if (expectedUser != null && session.userId != expectedUser) {
      throw const MemberAccountMismatch();
    }
    _adoptSession(session);
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

  Future<MemberAuthResult> _authenticate(MemberAuthIntent intent) async {
    _set(const AuthState(phase: AuthPhase.loading));
    try {
      final session = await _repository.authenticate(intent);
      _adoptSession(session);
      return MemberAuthResult.authenticated;
    } on MemberAuthCancelled {
      _set(const AuthState(phase: AuthPhase.signedOut));
      return MemberAuthResult.cancelled;
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
