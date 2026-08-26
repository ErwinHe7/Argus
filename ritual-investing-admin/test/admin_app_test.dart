import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_admin/application/admin_session_controller.dart';
import 'package:ritual_investing_admin/data/admin_gateway.dart';
import 'package:ritual_investing_admin/domain/admin_models.dart';
import 'package:ritual_investing_admin/ui/admin_app.dart';

void main() {
  testWidgets('hides unauthorized areas and protects direct navigation', (
    tester,
  ) async {
    final session = AdminSessionController.fixture(
      permissions: const {'admin:editorial:read'},
    );
    await tester.pumpWidget(
      AdminApp(
        session: session,
        gateway: FixtureAdminGateway(),
        initialLocation: '/editorial/rituals',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ritual scenarios'), findsWidgets);
    expect(find.text('Privacy requests'), findsNothing);

    session.goTo('/operations/privacy');
    await tester.pumpAndSettle();
    expect(
      find.text('You do not have access to this workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('uses navigation rail on desktop and drawer on compact widths', (
    tester,
  ) async {
    final session = AdminSessionController.fixture(
      permissions: AdminPermission.all,
    );
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AdminApp(session: session, gateway: FixtureAdminGateway()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });

  testWidgets('supports keyboard focus and a reviewed draft workflow', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway(
      records: const [
        AdminRecord(
          id: 'item-1',
          title: 'The Compass',
          status: 'draft',
          version: 1,
          revisionId: 'revision-1',
        ),
      ],
    );
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
    await tester.tap(find.text('The Compass'));
    await tester.pump();
    await tester.tap(find.text('Request review'));
    await tester.pumpAndSettle();

    expect(gateway.transitions, contains('review:item-1:revision-1'));
    expect(find.text('Status: in_review'), findsOneWidget);
  });

  testWidgets('exposes the complete editorial decision controls', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway(
      records: const [
        AdminRecord(
          id: 'item-1',
          title: 'The Compass',
          status: 'in_review',
          version: 1,
          revisionId: 'revision-1',
        ),
      ],
    );
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
    await tester.tap(find.text('The Compass'));
    await tester.pump();
    for (final label in [
      'New revision',
      'Edit draft',
      'Preview',
      'Request review',
      'Approve',
      'Request changes',
      'Publish',
      'Withdraw',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(gateway.transitions, contains('approved:item-1'));

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(gateway.transitions, contains('preview:item-1'));

    await tester.ensureVisible(find.text('Withdraw'));
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(gateway.transitions, contains('withdraw:item-1'));
  });

  testWidgets('validates the guided media upload form before dispatch', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway();
    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: gateway,
        initialLocation: '/operations/media',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload request'));
    await tester.pumpAndSettle();

    expect(find.text('MIME type'), findsOneWidget);
    expect(find.text('Byte size'), findsOneWidget);
    expect(find.text('SHA-256 checksum'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Byte size is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '1024');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      List.filled(64, 'a').join(),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(gateway.transitions, contains('media-upload'));
  });

  testWidgets('surfaces stale ETag conflicts without losing navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: _ConflictGateway(),
        initialLocation: '/editorial/rituals',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conflicted draft'));
    await tester.pump();
    await tester.tap(find.text('Request review'));
    await tester.pumpAndSettle();

    expect(
      find.text('This record changed. Refresh before retrying the transition.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });

  testWidgets('wires schedule, media, moderation, privacy, and job controls', (
    tester,
  ) async {
    Future<FixtureAdminGateway> open(String route, String action) async {
      final gateway = FixtureAdminGateway(
        records: const [
          AdminRecord(
            id: 'record-1',
            title: 'Operational record',
            status: 'ready',
            version: 1,
            revisionId: 'revision-1',
          ),
        ],
      );
      await tester.pumpWidget(
        AdminApp(
          key: ValueKey('$route-${gateway.hashCode}'),
          session: AdminSessionController.fixture(
            permissions: AdminPermission.all,
          ),
          gateway: gateway,
          initialLocation: route,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operational record'));
      await tester.pump();
      expect(find.text(action), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      return gateway;
    }

    expect(
      (await open('/catalog/schedules', 'Withdraw schedule')).transitions,
      contains('schedule-withdraw:record-1'),
    );
    expect(
      (await open('/operations/media', 'Retire media')).transitions,
      contains('media-retire:record-1'),
    );
    expect(
      (await open('/moderation', 'Open case')).transitions,
      contains('moderation-open:record-1'),
    );
    expect(
      (await open('/operations/privacy', 'Retry request')).transitions,
      contains('privacy-retry:record-1'),
    );
    expect(
      (await open('/operations/jobs', 'Retry job')).transitions,
      contains('job-retry:record-1'),
    );
  });

  testWidgets('keeps audit read-only and gates Coven verification separately', (
    tester,
  ) async {
    final record = const AdminRecord(
      id: 'record-1',
      title: 'Audit record',
      status: 'allowed',
      version: 1,
      revisionId: 'revision-1',
    );
    await tester.pumpWidget(
      AdminApp(
        key: const ValueKey('audit-workspace'),
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: FixtureAdminGateway(records: [record]),
        initialLocation: '/operations/audit',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audit record'));
    await tester.pump();
    expect(find.text('Retry job'), findsNothing);
    expect(find.text('Edit record'), findsNothing);

    final coven = FixtureAdminGateway(
      records: const [
        AdminRecord(
          id: 'entry-1',
          title: 'Coven entry',
          status: 'in_review',
          version: 1,
          revisionId: 'revision-1',
        ),
      ],
    );
    await tester.pumpWidget(
      AdminApp(
        key: ValueKey('coven-${coven.hashCode}'),
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: coven,
        initialLocation: '/editorial/coven',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coven entry'));
    await tester.pump();
    expect(find.text('Verify qualification'), findsOneWidget);
  });
}

class _ConflictGateway extends FixtureAdminGateway {
  _ConflictGateway()
    : super(
        records: const [
          AdminRecord(
            id: 'conflict-1',
            title: 'Conflicted draft',
            status: 'draft',
            version: 2,
            revisionId: 'revision-2',
          ),
        ],
      );

  @override
  Future<void> requestReview(AdminDestination destination, AdminRecord record) {
    final request = RequestOptions(path: destination.apiPath);
    throw DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: 409),
    );
  }
}
