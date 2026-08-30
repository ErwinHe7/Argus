import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_admin/application/admin_session_controller.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';
import 'package:ritual_investing_admin/domain/admin_models.dart';
import 'package:ritual_investing_admin/ui/admin_app.dart';

import '../test/support/starpath_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // This suite proves browser rendering and permission-aware UI behavior with
  // deterministic fixtures. Supabase hosted-development Auth, live HTTP, and
  // the intentionally disabled production entrypoint remain deployment gates.

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
    expect(find.text('Status: approved'), findsOneWidget);
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

  testWidgets('staff can inspect the typed Starpath preview in the browser', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: FixtureAdminGateway(
          records: [
            AdminRecord(
              id: 'item-1',
              title: 'The Share Sigil',
              status: 'submitted',
              version: 1,
              revisionId: '11111111-1111-4111-8111-111111111111',
              payload: starpathLessonFixture(),
            ),
          ],
        ),
        initialLocation: '/editorial/starpath',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Share Sigil').first);
    await tester.pumpAndSettle();

    expect(find.text('Mythic mnemonic — memory aid only'), findsOneWidget);
    expect(find.text('Dated evidence'), findsOneWidget);
  });
}
