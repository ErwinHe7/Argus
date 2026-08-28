import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
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

  test(
    'recent-auth failure preserves the signed-in session and reaches caller',
    () async {
      final failure = StateError('recent authentication cancelled');
      final repository = _FakeSessionRepository(authenticationError: failure);
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
      await controller.restore();

      await expectLater(
        controller.reauthenticate(const Duration(minutes: 5)),
        throwsA(same(failure)),
      );

      expect(controller.state.phase, AuthPhase.signedIn);
    },
  );

  test(
    'sensitive actions fail closed until the server receipt port is wired',
    () async {
      final repository = _FakeSessionRepository(
        authenticatedSession: const AuthSession(
          accessToken: 'fresh-access-token',
          userId: '11111111-1111-4111-8111-111111111111',
          sessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
      );
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);

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

      expect(controller.state.phase, AuthPhase.failure);
      expect(controller.activeSession?.accessToken, 'first');
      expect(controller.state.message, contains('did not match'));
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

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    this.failLogout = false,
    this.authenticationError,
    this.authenticatedSession,
  });

  final bool failLogout;
  final Object? authenticationError;
  final AuthSession? authenticatedSession;
  int credentialReads = 0;

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
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    if (authenticationError case final error?) throw error;
    return authenticatedSession ??
        const AuthSession(accessToken: 'access-token');
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
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      current ?? const AuthSession(accessToken: 'access');

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
