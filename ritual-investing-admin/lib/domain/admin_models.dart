import 'package:flutter/foundation.dart';

abstract final class AdminPermission {
  static const editorialRead = 'admin:editorial:read';
  static const editorialWrite = 'admin:editorial:write';
  static const editorialReview = 'admin:editorial:review';
  static const editorialPublish = 'admin:editorial:publish';
  static const catalogRead = 'admin:catalog:read';
  static const catalogWrite = 'admin:catalog:write';
  static const covenVerify = 'admin:coven:verify';
  static const moderationRead = 'admin:moderation:read';
  static const moderationWrite = 'admin:moderation:write';
  static const mediaRead = 'admin:media:read';
  static const mediaWrite = 'admin:media:write';
  static const privacyRead = 'admin:privacy:read';
  static const privacyRetry = 'admin:privacy:write';
  static const operationsRead = 'admin:operations:read';
  static const operationsRetry = 'admin:operations:write';
  static const auditRead = 'admin:audit:read';

  static const all = <String>{
    editorialRead,
    editorialWrite,
    editorialReview,
    editorialPublish,
    catalogRead,
    catalogWrite,
    covenVerify,
    moderationRead,
    moderationWrite,
    mediaRead,
    mediaWrite,
    privacyRead,
    privacyRetry,
    operationsRead,
    operationsRetry,
    auditRead,
  };
}

enum AdminWorkspaceKind { editorial, catalog, verification, operations }

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
    this.highTrust = false,
  });

  final String route;
  final String title;
  final String subtitle;
  final String apiPath;
  final String readPermission;
  final String? writePermission;
  final AdminWorkspaceKind kind;
  final bool highTrust;
}

const adminDestinations = <AdminDestination>[
  AdminDestination(
    route: '/editorial/rituals',
    title: 'Ritual scenarios',
    subtitle: 'Draft, independently review, schedule, publish, or withdraw ritual guidance.',
    apiPath: '/v1/admin/ritual-scenarios',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    highTrust: true,
  ),
  AdminDestination(
    route: '/editorial/asset-codex',
    title: 'Asset Codex',
    subtitle: 'Maintain dated, evidenced Demo asset explanations and risks.',
    apiPath: '/v1/admin/asset-codex',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
  ),
  AdminDestination(
    route: '/editorial/coven',
    title: "Founders' Coven",
    subtitle: 'Curate fictional-company entries with independently verified qualifications.',
    apiPath: '/v1/admin/coven-entries',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
  ),
  AdminDestination(
    route: '/editorial/grimoires',
    title: 'Grimoires',
    subtitle: 'Review versioned curated collections and their evidence.',
    apiPath: '/v1/admin/grimoires',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
  ),
  AdminDestination(
    route: '/editorial/circle-templates',
    title: 'Circle templates',
    subtitle: 'Manage fictional community templates and frozen allocations.',
    apiPath: '/v1/admin/circle-templates',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
  ),
  AdminDestination(
    route: '/editorial/rowan',
    title: 'Rowan scripts',
    subtitle: 'Review constrained, non-coercive assistant copy before release.',
    apiPath: '/v1/admin/rowan-scripts',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
    highTrust: true,
  ),
  AdminDestination(
    route: '/editorial/briefings',
    title: 'Briefing templates',
    subtitle: 'Version Daily, weekly, and moon-cycle briefing structures.',
    apiPath: '/v1/admin/briefing-templates',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialWrite,
    kind: AdminWorkspaceKind.editorial,
  ),
  AdminDestination(
    route: '/catalog/assets',
    title: 'Assets',
    subtitle:
        'Maintain the Demo-only asset catalog and immutable metric snapshots.',
    apiPath: '/v1/admin/assets',
    readPermission: AdminPermission.catalogRead,
    writePermission: AdminPermission.catalogWrite,
    kind: AdminWorkspaceKind.catalog,
  ),
  AdminDestination(
    route: '/catalog/evidence',
    title: 'Evidence',
    subtitle: 'Review allowlisted HTTPS sources and dated claims.',
    apiPath: '/v1/admin/evidence-sources',
    readPermission: AdminPermission.catalogRead,
    writePermission: AdminPermission.catalogWrite,
    kind: AdminWorkspaceKind.catalog,
  ),
  AdminDestination(
    route: '/catalog/evidence-claims',
    title: 'Evidence claims',
    subtitle: 'Create dated claims without rewriting source history.',
    apiPath: '/v1/admin/evidence-claims',
    readPermission: AdminPermission.catalogRead,
    writePermission: AdminPermission.catalogWrite,
    kind: AdminWorkspaceKind.catalog,
  ),
  AdminDestination(
    route: '/catalog/schedules',
    title: 'Ritual schedules',
    subtitle: 'Schedule approved revisions while preserving frozen member assignments.',
    apiPath: '/v1/admin/ritual-schedules',
    readPermission: AdminPermission.editorialRead,
    writePermission: AdminPermission.editorialPublish,
    kind: AdminWorkspaceKind.catalog,
    highTrust: true,
  ),
  AdminDestination(
    route: '/community/seeded-creators',
    title: 'Seeded creators',
    subtitle: 'Manage clearly fictional Demo community identities.',
    apiPath: '/v1/admin/seeded-creators',
    readPermission: AdminPermission.catalogRead,
    writePermission: AdminPermission.catalogWrite,
    kind: AdminWorkspaceKind.catalog,
  ),
  AdminDestination(
    route: '/moderation',
    title: 'Moderation',
    subtitle: 'Triage redacted reports and record immutable decisions.',
    apiPath: '/v1/admin/moderation/reports',
    readPermission: AdminPermission.moderationRead,
    writePermission: AdminPermission.moderationWrite,
    kind: AdminWorkspaceKind.operations,
  ),
  AdminDestination(
    route: '/operations/media',
    title: 'Media',
    subtitle: 'Inspect quarantine, scan, derivative, and reference state.',
    apiPath: '/v1/admin/media',
    readPermission: AdminPermission.mediaRead,
    writePermission: AdminPermission.mediaWrite,
    kind: AdminWorkspaceKind.operations,
  ),
  AdminDestination(
    route: '/operations/privacy',
    title: 'Privacy requests',
    subtitle: 'Observe export and deletion lifecycles without download access.',
    apiPath: '/v1/admin/privacy/requests',
    readPermission: AdminPermission.privacyRead,
    writePermission: AdminPermission.privacyRetry,
    kind: AdminWorkspaceKind.operations,
    highTrust: true,
  ),
  AdminDestination(
    route: '/operations/jobs',
    title: 'Job operations',
    subtitle: 'Inspect redacted Queue state and replay terminal jobs safely.',
    apiPath: '/v1/admin/jobs',
    readPermission: AdminPermission.operationsRead,
    writePermission: AdminPermission.operationsRetry,
    kind: AdminWorkspaceKind.operations,
  ),
  AdminDestination(
    route: '/operations/audit',
    title: 'Audit log',
    subtitle: 'Search immutable allowed and denied administrative events.',
    apiPath: '/v1/admin/audit-events',
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
