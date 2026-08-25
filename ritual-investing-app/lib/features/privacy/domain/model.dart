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
    required this.tombstoneId,
    required this.effectiveAt,
    required this.purgeBy,
    required this.purgeGeneration,
  });

  final String requestId;
  final String tombstoneId;
  final DateTime effectiveAt;
  final DateTime purgeBy;
  final int purgeGeneration;
}

@immutable
class DemoResetReceipt {
  const DemoResetReceipt({
    required this.resetGeneration,
    required this.defaultPortfolioId,
  });

  final int resetGeneration;
  final String defaultPortfolioId;
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
