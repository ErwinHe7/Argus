import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/auth0_session_repository.dart';

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
}

class _FakeSessionRepository implements SessionRepository {
  int credentialReads = 0;
  @override
  Future<AuthSession?> credentials() async {
    credentialReads++;
    return AuthSession(
      accessToken: credentialReads == 1 ? 'access-token' : 'access-token-2',
    );
  }

  @override
  Future<AuthSession> login() async =>
      const AuthSession(accessToken: 'access-token');
  @override
  Future<void> logout() async {}
}
