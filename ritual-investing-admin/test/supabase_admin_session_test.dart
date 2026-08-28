import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_admin/application/admin_session_controller.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';

class _Credentials implements AdminCredentialRepository {
  AdminCredentialSnapshot? snapshot = const AdminCredentialSnapshot(
    accessToken: 'supabase-token',
    assuranceLevel: AdminAssuranceLevel.aal2,
  );
  bool globalLogout = false;

  @override
  Future<AdminCredentialSnapshot?> freshCredential() async => snapshot;
  @override
  Future<AdminCredentialSnapshot?> login() async => snapshot;
  @override
  Future<AdminCredentialSnapshot?> verifySecondFactor(String code) async {
    snapshot = const AdminCredentialSnapshot(
      accessToken: 'aal2-token',
      assuranceLevel: AdminAssuranceLevel.aal2,
    );
    return snapshot;
  }

  @override
  Future<void> logout({required bool global}) async {
    globalLogout = global;
    snapshot = null;
  }

  @override
  Future<AdminCredentialSnapshot?> restore() async => snapshot;
}

void main() {
  test(
    'selects only one verified TOTP factor and rejects ambiguous factors',
    () {
      expect(
        selectSingleVerifiedTotpFactor(
          verifiedFactorIds: const ['totp-1'],
          verifiedTotpFactorIds: const ['totp-1'],
        ),
        'totp-1',
      );
      for (final factors in [
        (verified: <String>[], totp: <String>[]),
        (verified: ['totp-1', 'totp-2'], totp: ['totp-1', 'totp-2']),
        (verified: ['phone-1'], totp: <String>[]),
      ]) {
        expect(
          () => selectSingleVerifiedTotpFactor(
            verifiedFactorIds: factors.verified,
            verifiedTotpFactorIds: factors.totp,
          ),
          throwsStateError,
        );
      }
    },
  );

  test('requires Supabase AAL2 before loading sensitive staff state', () async {
    final credentials = _Credentials()
      ..snapshot = const AdminCredentialSnapshot(
        accessToken: 'aal1-token',
        assuranceLevel: AdminAssuranceLevel.aal1,
      );
    final controller = AdminSessionController(credentials: credentials)
      ..attachGateway(FixtureAdminGateway());

    await controller.restore();

    expect(controller.phase, AdminSessionPhase.requiresAal2);
    expect(controller.session, isNull);
    expect(await controller.accessToken(), isNull);
  });

  test('global logout clears the staff token and dashboard state', () async {
    final credentials = _Credentials();
    final controller = AdminSessionController(credentials: credentials)
      ..attachGateway(FixtureAdminGateway());
    await controller.restore();
    expect(controller.isReady, isTrue);

    await controller.logout();

    expect(credentials.globalLogout, isTrue);
    expect(controller.phase, AdminSessionPhase.signedOut);
    expect(controller.session, isNull);
    expect(await controller.accessToken(), isNull);
  });

  test(
    'an enrolled TOTP challenge promotes AAL1 before staff data loads',
    () async {
      final credentials = _Credentials()
        ..snapshot = const AdminCredentialSnapshot(
          accessToken: 'aal1-token',
          assuranceLevel: AdminAssuranceLevel.aal1,
        );
      final controller = AdminSessionController(credentials: credentials)
        ..attachGateway(FixtureAdminGateway());
      await controller.restore();

      await controller.verifySecondFactor('123456');

      expect(controller.phase, AdminSessionPhase.ready);
      expect(controller.session, isNotNull);
      expect(await controller.accessToken(), 'aal2-token');
    },
  );
}
