import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'member auth preserves restore, hosted sign-in, recovery, and global logout states',
    (tester) async {
      final repository = _IntegrationSessionRepository();
      final controller = AuthController(repository: repository);
      addTearDown(controller.dispose);
      addTearDown(repository.close);

      await controller.restore();
      expect(controller.state.phase, AuthPhase.signedOut);

      expect(await controller.signIn(), MemberAuthResult.authenticated);
      expect(controller.state.phase, AuthPhase.signedIn);
      expect(
        controller.activeSession?.userId,
        _IntegrationSessionRepository.userId,
      );

      repository.emitRecovery();
      await tester.pump();
      expect(controller.state.isPasswordRecovery, isTrue);

      await controller.logoutEverywhere();
      expect(repository.logoutScopes, [MemberLogoutScope.global]);
      expect(controller.state.phase, AuthPhase.signedOut);
    },
  );
}

class _IntegrationSessionRepository
    implements SessionRepository, SessionChangeRepository, ScopedSessionLogout {
  static const userId = '11111111-1111-4111-8111-111111111111';
  static const sessionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  static const session = AuthSession(
    accessToken: 'integration-access-token',
    userId: userId,
    sessionId: sessionId,
  );

  final StreamController<MemberSessionChange> _changes =
      StreamController.broadcast(sync: true);
  final List<MemberLogoutScope> logoutScopes = [];
  AuthSession? current;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(
        issuer: 'https://project.supabase.co/auth/v1',
      );

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Stream<MemberSessionChange> get sessionChanges => _changes.stream;

  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async {
    current = session;
    _changes.add(
      const MemberSessionChange(
        event: MemberSessionEvent.signedIn,
        session: session,
      ),
    );
    return session;
  }

  void emitRecovery() => _changes.add(
    const MemberSessionChange(
      event: MemberSessionEvent.passwordRecovery,
      session: session,
    ),
  );

  @override
  Future<AuthSession?> recover() async => current;

  @override
  Future<void> logout() => logoutWithScope(MemberLogoutScope.local);

  @override
  Future<void> logoutWithScope(MemberLogoutScope scope) async {
    logoutScopes.add(scope);
    current = null;
    _changes.add(
      const MemberSessionChange(event: MemberSessionEvent.signedOut),
    );
  }

  Future<void> close() => _changes.close();
}
