import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/auth/member_auth_signal_base.dart';
import 'package:ritual_investing_app/core/auth/member_step_up.dart';

void main() {
  test(
    'auth controller delegates credentials refresh to the SDK repository',
    () async {
      final repository = _FakeSessionRepository();
      final controller = AuthController(repository: repository);
      await controller.restore();
      expect(controller.state.phase, AuthPhase.signedIn);
      expect(repository.credentialReads, 1);
      expect(await controller.accessToken(), 'access-token-2');
      expect(await controller.accessToken(), 'access-token-2');
      expect(repository.credentialReads, 3);
    },
  );

  test('unexpected password-recovery events fail closed', () async {
    final repository = _StreamingSessionRepository();
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    repository.emit(
      const MemberSessionChange(
        event: MemberSessionEvent.signedIn,
        session: AuthSession(accessToken: 'normal'),
      ),
    );

    repository.emit(
      const MemberSessionChange(
        event: MemberSessionEvent.passwordRecovery,
        session: AuthSession(accessToken: 'recovery'),
      ),
    );
    expect(controller.state.phase, AuthPhase.signedOut);
    expect(controller.activeSession, isNull);
  });

  test('token-free logout signal invalidates a sibling tab', () async {
    final repository = _StreamingSessionRepository();
    final signal = _FakeAuthSignal();
    final controller = AuthController(
      repository: repository,
      authSignal: signal,
    );
    addTearDown(controller.dispose);
    repository.emit(
      const MemberSessionChange(
        event: MemberSessionEvent.signedIn,
        session: AuthSession(accessToken: 'private-token'),
      ),
    );
    final invalidated = expectLater(
      controller.invalidatedSessions,
      emits(null),
    );

    signal.emitLogout();
    await invalidated;

    expect(controller.state.phase, AuthPhase.signedOut);
    expect(repository.logoutScopes, [MemberLogoutScope.local]);
    expect(signal.published, 0);
  });

  test('Google sign in adopts an immediately returned session', () async {
    final repository = _FakeSessionRepository(
      authenticatedSession: const AuthSession(
        accessToken: 'google-access-token',
        userId: '11111111-1111-4111-8111-111111111111',
      ),
    );
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);

    final result = await controller.signInWithGoogle();

    expect(result, MemberAuthResult.authenticated);
    expect(controller.state.phase, AuthPhase.signedIn);
    expect(controller.activeSession?.accessToken, 'google-access-token');
    expect(repository.googleSignIns, 1);
  });

  test(
    'Google sign in reports unavailable provider without exposing internals',
    () async {
      final controller = AuthController(
        repository: _FakeSessionRepository(
          authenticationError: const MemberAuthUnavailable('provider_disabled'),
        ),
      );
      addTearDown(controller.dispose);

      final result = await controller.signInWithGoogle();

      expect(result, MemberAuthResult.unavailable);
      expect(controller.state.phase, AuthPhase.failure);
      expect(
        controller.state.message,
        'Google sign-in is not enabled for this app yet.',
      );
    },
  );

  test(
    'logout returns to signed out when the repository logout fails',
    () async {
      final repository = _FakeSessionRepository(failLogout: true);
      final controller = AuthController(repository: repository);
      await controller.restore();
      controller.markBootstrapFailure();

      await expectLater(controller.logout(), completes);

      expect(controller.state.phase, AuthPhase.signedOut);
    },
  );

  test('stale Google session requires recent authentication', () async {
    final now = DateTime.now().toUtc();
    final repository = _FakeSessionRepository(
      authenticatedSession: AuthSession(
        accessToken: 'stale-google-session',
        userId: '11111111-1111-4111-8111-111111111111',
        authenticatedAt: now.subtract(const Duration(minutes: 10)),
      ),
    );
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    await controller.signInWithGoogle();

    await expectLater(
      controller.reauthenticate(const Duration(minutes: 5)),
      throwsA(
        isA<MemberAuthUnavailable>().having(
          (error) => error.reason,
          'reason',
          'recent_authentication_required',
        ),
      ),
    );

    expect(controller.state.phase, AuthPhase.signedIn);
  });

  test(
    'sensitive actions fail closed until the server receipt port is wired',
    () async {
      final repository = _FakeSessionRepository(
        authenticatedSession: AuthSession(
          accessToken: 'fresh-access-token',
          userId: '11111111-1111-4111-8111-111111111111',
          sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          authenticatedAt: DateTime.now().toUtc(),
        ),
      );
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
      await controller.signInWithGoogle();

      await expectLater(
        controller.authorizeSensitiveAction(SensitiveMemberAction.argusDelete),
        throwsA(isA<StepUpUnavailable>()),
      );
    },
  );

  test('auth-stream refresh failure is handled as recoverable state', () async {
    final repository = _StreamingSessionRepository();
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);
    repository.emit(
      const MemberSessionChange(
        event: MemberSessionEvent.signedIn,
        session: AuthSession(
          accessToken: 'access',
          userId: '11111111-1111-4111-8111-111111111111',
          sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
      ),
    );

    repository.fail(StateError('offline refresh'));

    expect(controller.state.phase, AuthPhase.failure);
    expect(controller.state.canLogout, isTrue);
    expect(controller.state.message, contains('could not be refreshed'));
  });

  test(
    'stream callback for another user cannot replace active app identity',
    () {
      final repository = _StreamingSessionRepository();
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
      repository.emit(
        const MemberSessionChange(
          event: MemberSessionEvent.signedIn,
          session: AuthSession(
            accessToken: 'first',
            userId: '11111111-1111-4111-8111-111111111111',
            sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          ),
        ),
      );

      repository.emit(
        const MemberSessionChange(
          event: MemberSessionEvent.signedIn,
          session: AuthSession(
            accessToken: 'second',
            userId: '22222222-2222-4222-8222-222222222222',
            sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          ),
        ),
      );

      expect(controller.state.phase, AuthPhase.signedOut);
      expect(controller.activeSession, isNull);
    },
  );

  test(
    'global logout is explicit and local state clears on remote failure',
    () async {
      final repository = _StreamingSessionRepository(failLogout: true);
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
      repository.emit(
        const MemberSessionChange(
          event: MemberSessionEvent.signedIn,
          session: AuthSession(accessToken: 'access'),
        ),
      );

      await expectLater(controller.logoutEverywhere(), completes);

      expect(repository.logoutScopes, [MemberLogoutScope.global]);
      expect(controller.state.phase, AuthPhase.signedOut);
      expect(controller.activeSession, isNull);
    },
  );
}

class _FakeSessionRepository
    implements SessionRepository, GoogleOAuthSessionRepository {
  _FakeSessionRepository({
    this.failLogout = false,
    this.authenticationError,
    this.authenticatedSession,
  });

  final bool failLogout;
  final Object? authenticationError;
  final AuthSession? authenticatedSession;
  int credentialReads = 0;
  int googleSignIns = 0;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://member-auth.test/auth/v1');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession?> recover() async {
    credentialReads++;
    return AuthSession(
      accessToken: credentialReads == 1 ? 'access-token' : 'access-token-2',
    );
  }

  @override
  Future<AuthSession?> signInWithGoogle() async {
    googleSignIns += 1;
    if (authenticationError case final error?) throw error;
    return authenticatedSession ??
        const AuthSession(accessToken: 'google-access-token');
  }

  @override
  Future<void> logout() async {
    if (failLogout) throw StateError('Auth logout failed');
  }
}

class _StreamingSessionRepository
    implements SessionRepository, SessionChangeRepository, ScopedSessionLogout {
  _StreamingSessionRepository({this.failLogout = false});

  final bool failLogout;
  final StreamController<MemberSessionChange> _changes =
      StreamController.broadcast(sync: true);
  final List<MemberLogoutScope> logoutScopes = [];
  AuthSession? current;

  void emit(MemberSessionChange change) {
    current = change.session;
    _changes.add(change);
  }

  void fail(Object error) => _changes.addError(error);

  @override
  Stream<MemberSessionChange> get sessionChanges => _changes.stream;

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(
        issuer: 'https://project.supabase.co/auth/v1',
      );

  @override
  Future<AuthSession?> recover() async => current;

  @override
  Future<void> logout() => logoutWithScope(MemberLogoutScope.local);

  @override
  Future<void> logoutWithScope(MemberLogoutScope scope) async {
    logoutScopes.add(scope);
    if (failLogout) throw StateError('offline');
    current = null;
  }
}

class _FakeAuthSignal implements MemberAuthSignal {
  final StreamController<void> _events = StreamController.broadcast(sync: true);
  int published = 0;

  void emitLogout() => _events.add(null);

  @override
  Stream<void> get logoutEvents => _events.stream;
  @override
  void publishLogout() => published += 1;
  @override
  void close() => _events.close();
}
