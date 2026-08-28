import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_admin/application/admin_session_controller.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';
import 'package:ritual_investing_admin/domain/admin_models.dart';
import 'package:ritual_investing_admin/ui/admin_app.dart';

class _Aal2Credentials implements AdminCredentialRepository {
  const _Aal2Credentials();

  static const snapshot = AdminCredentialSnapshot(
    accessToken: 'supabase-staff-token',
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
  Future<void> logout({required bool global}) async {}
  @override
  Future<AdminCredentialSnapshot?> restore() async => snapshot;
}

class _RevokedStaffGateway extends FixtureAdminGateway {
  @override
  Future<AdminStaffSession> loadSession() async {
    final request = RequestOptions(path: '/v1/admin/session');
    throw DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: 403),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'revoked Supabase staff receives 403 teardown before data renders',
    (tester) async {
      final session = AdminSessionController(
        credentials: const _Aal2Credentials(),
      );
      await tester.pumpWidget(
        AdminApp(session: session, gateway: _RevokedStaffGateway()),
      );
      await tester.pumpAndSettle();

      expect(session.phase, AdminSessionPhase.denied);
      expect(session.session, isNull);
      expect(await session.accessToken(), isNull);
      expect(find.text('Ritual staff access'), findsOneWidget);
      expect(find.text('Ritual scenarios'), findsNothing);
    },
  );

  testWidgets('brokerage workspace renders only redacted diagnostic metadata', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway(
      records: const [
        AdminRecord(
          id: 'diag_8fd8fe6d7a4f',
          title: 'reconciliation',
          status: 'manual_review',
          version: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: const {AdminPermission.brokerageRead},
        ),
        gateway: gateway,
        initialLocation: '/operations/brokerage',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('reconciliation'));
    await tester.pump();

    expect(find.text('Status: manual_review'), findsOneWidget);
    expect(find.text('Place order'), findsNothing);
    expect(find.text('Retry job'), findsNothing);
    expect(find.textContaining('balance'), findsNothing);
    expect(find.textContaining('credential'), findsNothing);
  });
}
