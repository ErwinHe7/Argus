import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_admin/application/admin_session_controller.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';

class _Credentials implements AdminCredentialRepository {
  AdminCredentialSnapshot? snapshot = const AdminCredentialSnapshot(
    accessToken: 'initial',
    assuranceLevel: AdminAssuranceLevel.aal2,
  );
  @override
  Future<AdminCredentialSnapshot?> freshCredential() async => snapshot;
  @override
  Future<AdminCredentialSnapshot?> login() async => snapshot;
  @override
  Future<AdminCredentialSnapshot?> verifySecondFactor(String code) async =>
      snapshot;
  @override
  Future<void> logout({required bool global}) async => snapshot = null;
  @override
  Future<AdminCredentialSnapshot?> restore() async => snapshot;
}

void main() {
  test('refreshes credentials and revokes a stale dashboard session', () async {
    final credentials = _Credentials();
    final controller = AdminSessionController(credentials: credentials)
      ..attachGateway(FixtureAdminGateway());
    await controller.restore();
    expect(controller.isReady, isTrue);
    expect(await controller.accessToken(), 'initial');

    credentials.snapshot = null;
    expect(await controller.accessToken(), isNull);
    expect(controller.phase, AdminSessionPhase.signedOut);
    expect(controller.session, isNull);
  });

  test('API authorization denial tears down the staff session', () async {
    final controller = AdminSessionController(credentials: _Credentials())
      ..attachGateway(FixtureAdminGateway());
    await controller.restore();

    controller.handleAuthorizationDenied(403);

    expect(controller.phase, AdminSessionPhase.denied);
    expect(controller.session, isNull);
    expect(await controller.accessToken(), isNull);
  });
}
