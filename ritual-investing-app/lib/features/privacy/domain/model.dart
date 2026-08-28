import 'package:flutter/foundation.dart';

enum PrivacyExportFormat { zip }

enum PrivacyExportStatus {
  requested,
  verified,
  queued,
  processing,
  completed,
  failed,
  cancelled,
}

enum PrivacyDeletionStatus {
  requested,
  verified,
  queued,
  processing,
  completed,
  failed,
  cancelled,
}

@immutable
class PrivacyExport {
  const PrivacyExport({
    required this.id,
    required this.status,
    required this.format,
    required this.hasDownloadGrant,
    this.snapshotAt,
    this.completedAt,
    this.expiresAt,
    this.failureCode,
  });

  final String id;
  final PrivacyExportStatus status;
  final PrivacyExportFormat format;
  final bool hasDownloadGrant;
  final DateTime? snapshotAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final String? failureCode;

  bool get isTerminal =>
      status == PrivacyExportStatus.failed ||
      status == PrivacyExportStatus.cancelled;
  bool get canDownload =>
      status == PrivacyExportStatus.completed && hasDownloadGrant;
}

@immutable
class PrivacyDeletionReceipt {
  const PrivacyDeletionReceipt({
    required this.requestId,
    required this.status,
    required this.requestedAt,
  });

  final String requestId;
  final PrivacyDeletionStatus status;
  final DateTime requestedAt;
}

enum PrivacyFailureKind { forbidden, conflict, throttled, retryable, terminal }

class PrivacyFailure implements Exception {
  const PrivacyFailure(this.kind);

  final PrivacyFailureKind kind;
}

class RecentAuthRequired implements Exception {
  const RecentAuthRequired();
}

class RecentAuthCancelled implements Exception {
  const RecentAuthCancelled();
}

class AccountInactive implements Exception {
  const AccountInactive();
}

class AmbiguousPrivacyMutation implements Exception {
  const AmbiguousPrivacyMutation();
}
