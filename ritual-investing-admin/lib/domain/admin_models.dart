import 'package:flutter/foundation.dart';

abstract final class AdminPermission {
  static const editorialRead = 'editorial:read';
  static const editorialWrite = 'editorial:write';
  static const editorialReview = 'editorial:review';
  static const editorialPublish = 'editorial:publish';
  static const catalogRead = 'editorial:read';
  static const catalogWrite = 'editorial:write';
  static const covenVerify = 'editorial:review';
  static const moderationRead = 'moderation:read';
  static const moderationWrite = 'moderation:write';
  static const mediaRead = 'media:read';
  static const mediaWrite = 'media:write';
  static const privacyRead = 'privacy:read';
  static const privacyRetry = 'privacy:write';
  static const operationsRead = 'operations:read';
  static const operationsRetry = 'operations:write';
  static const auditRead = 'audit:read';
  static const brokerageRead = 'brokerage:read';

  static const all = <String>{
    editorialRead,
    editorialWrite,
    editorialReview,
    editorialPublish,
    moderationRead,
    moderationWrite,
    mediaRead,
    mediaWrite,
    privacyRead,
    privacyRetry,
    operationsRead,
    operationsRetry,
    auditRead,
    brokerageRead,
  };
}

enum AdminWorkspaceKind { editorial, catalog, verification, operations }

enum AdminReviewDecision {
  approved('approved'),
  changesRequested('changes_requested');

  const AdminReviewDecision(this.wireValue);
  final String wireValue;
}

@immutable
class AdminDestination {
  const AdminDestination({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.apiPath,
    required this.readPermission,
    required this.kind,
    this.writePermission,
    this.editorialKind,
    this.highTrust = false,
  });

  final String route;
  final String title;
  final String subtitle;
  final String apiPath;
  final String readPermission;
  final String? writePermission;
  final String? editorialKind;
  final AdminWorkspaceKind kind;
  final bool highTrust;
}

const adminDestinations = <AdminDestination>[
  AdminDestination(
    route: '/editorial/rituals',
    title: 'Ritual scenarios',
    subtitle: 'Draft, independently review, schedule, publish, or withdraw ritual guidance.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'ritual',
    highTrust: true,
  ),
  AdminDestination(
    route: '/editorial/asset-codex',
    title: 'Asset Codex',
    subtitle: 'Maintain dated, evidenced Demo asset explanations and risks.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'asset_codex',
  ),
  AdminDestination(
    route: '/editorial/coven',
    title: "Founders' Coven",
    subtitle: 'Curate fictional-company entries with independently verified qualifications.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'coven',
  ),
  AdminDestination(
    route: '/editorial/grimoires',
    title: 'Grimoires',
    subtitle: 'Review versioned curated collections and their evidence.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'grimoire',
  ),
  AdminDestination(
    route: '/editorial/circle-templates',
    title: 'Circle templates',
    subtitle: 'Manage fictional community templates and frozen allocations.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'circle_template',
  ),
  AdminDestination(
    route: '/editorial/rowan',
    title: 'Rowan scripts',
    subtitle: 'Review constrained, non-coercive assistant copy before release.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'rowan',
    highTrust: true,
  ),
  AdminDestination(
    route: '/editorial/briefings',
    title: 'Briefing templates',
    subtitle: 'Version Daily, weekly, and moon-cycle briefing structures.',
    apiPath: '/v1/admin/editorial',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    editorialKind: 'briefing_template',
  ),
  AdminDestination(
    route: '/operations/privacy',
    title: 'Privacy requests',
    subtitle: 'Observe export and deletion lifecycles without download access.',
    apiPath: '/v1/admin/operations/privacy',
    readPermission: AdminPermission.privacyRead,
    writePermission: AdminPermission.privacyRetry,
    kind: AdminWorkspaceKind.operations,
    highTrust: true,
  ),
  AdminDestination(
    route: '/operations/jobs',
    title: 'Job operations',
    subtitle: 'Inspect redacted Queue state and replay terminal jobs safely.',
    apiPath: '/v1/admin/operations/jobs',
    readPermission: AdminPermission.operationsRead,
    writePermission: AdminPermission.operationsRetry,
    kind: AdminWorkspaceKind.operations,
  ),
  AdminDestination(
    route: '/operations/brokerage',
    title: 'Brokerage diagnostics',
    subtitle: 'Inspect redacted Webull connection, command, and reconciliation health. No order controls or brokerage values are available.',
    apiPath: '/v1/admin/operations/brokerage',
    readPermission: AdminPermission.brokerageRead,
    kind: AdminWorkspaceKind.operations,
  ),
  AdminDestination(
    route: '/operations/audit',
    title: 'Audit log',
    subtitle: 'Search immutable allowed and denied administrative events.',
    apiPath: '/v1/admin/audit',
    readPermission: AdminPermission.auditRead,
    kind: AdminWorkspaceKind.operations,
  ),
];

@immutable
class AdminRecord {
  const AdminRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    this.revisionId,
    this.etag = '"v1"',
  });
  final String id;
  final String title;
  final String status;
  final int version;
  final String? revisionId;
  final String etag;
}

@immutable
class AdminStaffSession {
  const AdminStaffSession({
    required this.staffId,
    required this.displayLabel,
    required this.permissions,
    required this.revocationEpoch,
  });
  final String staffId;
  final String displayLabel;
  final Set<String> permissions;
  final int revocationEpoch;
}
