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
      permissions: const {AdminPermission.editorialRead},
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

  testWidgets('edits editorial revisions through typed domain fields', (
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
    await tester.tap(find.text('New revision'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scenario key'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('Idea asset IDs'), findsOneWidget);
    expect(find.text('Evidence claim IDs'), findsOneWidget);
    expect(find.text('Schema-bound payload'), findsNothing);
    expect(find.text('Typed JSON payload'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Observation timestamp'),
      'not-a-timestamp',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Idea asset IDs'),
      'not-a-uuid,still-not-a-uuid,also-not-a-uuid',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.text('Use an ISO-8601 timestamp with timezone.'),
      findsOneWidget,
    );
    expect(find.text('Enter valid UUIDs separated by commas.'), findsOneWidget);
  });

  testWidgets('Asset Codex edits preserve and append typed children', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway(
      records: [
        const AdminRecord(
          id: 'item-1',
          title: 'Atlas',
          status: 'draft',
          version: 1,
          revisionId: 'revision-1',
          payload: {
            'asset_id': '11111111-1111-4111-8111-111111111111',
            'appearance_reason': 'Existing reason',
            'thesis': 'Existing thesis',
            'limitations': 'Existing limits',
            'metrics_as_of': '2026-08-29T00:00:00Z',
            'metrics': [
              {
                'observed_at': '2026-08-28T00:00:00Z',
                'price_minor': 10,
                'source_label': 'Existing',
              },
            ],
            'risks': [
              {
                'title': 'Existing risk',
                'detail': 'Existing detail',
                'severity': 'low',
              },
            ],
          },
        ),
      ],
    );
    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: gateway,
        initialLocation: '/editorial/asset-codex',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atlas'));
    await tester.pump();
    await tester.tap(find.text('Edit draft'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Existing thesis'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Add risk title'),
      'New risk',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Add risk detail'),
      'New detail',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Add risk severity'),
      'high',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Add metric observed timestamp'),
      '2026-08-29T01:00:00Z',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Add metric price (minor units)'),
      '12',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(gateway.lastPatchedPayload!['metrics'], hasLength(2));
    expect(gateway.lastPatchedPayload!['risks'], hasLength(2));
  });

  testWidgets('Coven drafts require and send person_name and valid_to', (
    tester,
  ) async {
    final gateway = FixtureAdminGateway();
    await tester.pumpWidget(
      AdminApp(
        session: AdminSessionController.fixture(
          permissions: AdminPermission.all,
        ),
        gateway: gateway,
        initialLocation: '/editorial/coven',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New draft'));
    await tester.pump();
    for (final entry in <String, String>{
      'Stable slug': 'founder',
      'Company ID': '11111111-1111-4111-8111-111111111111',
      'Research focus': 'Focus',
      'Teaser': 'Teaser',
      'Summary': 'Summary',
      'Inclusion rationale': 'Rationale',
      'Limitations': 'Limits',
      'Effective date': '2026-02-28',
      'Verified as of': '2026-02-28',
      'Qualification criterion code': 'founder',
      'Qualified person name': 'Ava',
      'Qualification claim': 'Claim',
      'Qualification valid to': '2026-12-31',
    }.entries) {
      await tester.enterText(
        find.widgetWithText(TextFormField, entry.key),
        entry.value,
      );
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final qualifications = gateway.lastDraftPayload!['qualifications'] as List;
    expect(qualifications.single, containsPair('person_name', 'Ava'));
    expect(qualifications.single, containsPair('valid_to', '2026-12-31'));
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

  testWidgets(
    'wires stepped-up operations and keeps brokerage diagnostic-only',
    (tester) async {
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
        (await open('/operations/privacy', 'Retry request')).transitions,
        contains('privacy-retry:record-1'),
      );
      expect(
        (await open('/operations/jobs', 'Retry job')).transitions,
        contains('job-retry:record-1'),
      );

      final brokerage = FixtureAdminGateway(
        records: const [
          AdminRecord(
            id: 'diag-redacted',
            title: 'connection_health',
            status: 'temporarily_unavailable',
            version: 1,
          ),
        ],
      );
      await tester.pumpWidget(
        AdminApp(
          key: ValueKey('brokerage-${brokerage.hashCode}'),
          session: AdminSessionController.fixture(
            permissions: AdminPermission.all,
          ),
          gateway: brokerage,
          initialLocation: '/operations/brokerage',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('connection_health'));
      await tester.pump();
      expect(find.text('Retry job'), findsNothing);
      expect(find.text('Place order'), findsNothing);
      expect(find.textContaining('credential'), findsNothing);
    },
  );

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
