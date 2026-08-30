import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';

void main() {
  test('controller delegates sign-in and sign-up credentials', () async {
    final repository = _RecordingMemberAuthRepository();
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);

    await controller.signInWithPassword(
      email: 'member@example.com',
      password: 'sign-in-password',
    );
    await controller.signUpWithPassword(
      email: 'new-member@example.com',
      password: 'sign-up-password',
    );

    expect(repository.signIns, const [
      (email: 'member@example.com', password: 'sign-in-password'),
    ]);
    expect(repository.signUps, const [
      (email: 'new-member@example.com', password: 'sign-up-password'),
    ]);
    expect(
      controller.memberClientExpectation.issuer,
      'https://member-auth.test/auth/v1',
    );
  });

  test('recent authentication accepts a fresh password session', () async {
    final repository = _RecordingMemberAuthRepository(
      recoveredSession: AuthSession(
        accessToken: 'fresh-access-token',
        authenticatedAt: DateTime.now().toUtc(),
      ),
    );
    final controller = AuthController(repository: repository);
    addTearDown(controller.dispose);

    final session = await controller.reauthenticate(const Duration(minutes: 5));

    expect(session.accessToken, 'fresh-access-token');
    expect(repository.recoveryCalls, 1);
  });

  test(
    'credential recovery is attempted once for process restoration',
    () async {
      final repository = _RecordingMemberAuthRepository();
      final controller = AuthController(repository: repository);

      await controller.restore();

      expect(repository.recoveryCalls, 1);
      expect(controller.state.phase, AuthPhase.signedIn);
    },
  );
}

class _RecordingMemberAuthRepository
    implements SessionRepository, PasswordSessionRepository {
  _RecordingMemberAuthRepository({AuthSession? recoveredSession})
    : recoveredSession =
          recoveredSession ??
          const AuthSession(accessToken: 'recovered-access-token');

  final AuthSession recoveredSession;
  final List<({String email, String password})> signIns = [];
  final List<({String email, String password})> signUps = [];
  int recoveryCalls = 0;

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://member-auth.test/auth/v1');

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signIns.add((email: email, password: password));
    return const AuthSession(accessToken: 'sign-in-access-token');
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    signUps.add((email: email, password: password));
    return const AuthSession(accessToken: 'sign-up-access-token');
  }

  @override
  Future<AuthSession?> recover() async {
    recoveryCalls++;
    return recoveredSession;
  }

  @override
  Future<void> logout() async {}
}
