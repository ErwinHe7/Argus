import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';

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
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({this.failLogout = false, this.authenticationError});

  final bool failLogout;
  final Object? authenticationError;
  int credentialReads = 0;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'member-client');

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
    return const AuthSession(accessToken: 'access-token');
  }

  @override
  Future<void> logout() async {
    if (failLogout) throw StateError('Auth0 logout failed');
  }
}
