import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';

void main() {
  test('controller preserves SDK-free sign-in and sign-up intent', () async {
    final repository = _RecordingMemberAuthRepository();
    final controller = AuthController(repository: repository);

    await controller.signIn();
    await controller.signUp();

    expect(repository.intents, const [
      MemberAuthIntent.signIn(),
      MemberAuthIntent.signUp(),
    ]);
    expect(
      controller.memberClientExpectation.authorizedParty,
      'member-mobile-client',
    );
  });

  test('recent authentication retains the exact maxAge boundary', () async {
    final repository = _RecordingMemberAuthRepository();
    final controller = AuthController(repository: repository);

    await controller.reauthenticate(const Duration(minutes: 5));

    expect(
      repository.intents.single,
      const MemberAuthIntent.recentAuth(maxAge: Duration(minutes: 5)),
    );
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

class _RecordingMemberAuthRepository implements SessionRepository {
  final List<MemberAuthIntent> intents = [];
  int recoveryCalls = 0;

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'member-mobile-client');

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    intents.add(intent);
    return const AuthSession(accessToken: 'access-token');
  }

  @override
  Future<AuthSession?> recover() async {
    recoveryCalls++;
    return const AuthSession(accessToken: 'recovered-access-token');
  }

  @override
  Future<void> logout() async {}
}
