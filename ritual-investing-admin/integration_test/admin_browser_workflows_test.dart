import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_admin/application/admin_session_controller.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';
import 'package:ritual_investing_admin/domain/admin_models.dart';
import 'package:ritual_investing_admin/ui/admin_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('staff can review an editorial draft in the browser', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway(
      records: const [
        AdminRecord(
          id: 'ritual-1',
          title: 'North Star ritual',
          status: 'in_review',
          version: 2,
          revisionId: 'revision-2',
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: gateway,
        initialLocation: '/editorial/rituals',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('North Star ritual'));
    await tester.pump();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(gateway.transitions, contains('approved:ritual-1'));
    expect(find.text('Status: in_review'), findsOneWidget);
  });

  testWidgets('direct navigation stays permission protected in the browser', (
    tester,
  ) async {
    final session = AdminSessionController.fixture(
      permissions: const {AdminPermission.editorialRead},
    );

    await tester.pumpWidget(
      AdminApp(
        session: session,
        gateway: FixtureAdminGateway(),
        initialLocation: '/operations/privacy',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You do not have access to this workspace.'),
      findsOneWidget,
    );
    expect(find.text('Privacy requests'), findsNothing);
  });
}
