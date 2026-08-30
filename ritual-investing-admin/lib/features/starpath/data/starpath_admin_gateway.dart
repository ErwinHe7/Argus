import '../../../domain/admin_models.dart';
import '../domain/starpath_editorial_models.dart';

abstract interface class StarpathAdminGateway {
  Future<List<AdminRecord>> listStarpathLessons();
  Future<AdminRecord> loadStarpathRevision(AdminRecord record);
  Future<void> createStarpathLesson(String slug, Map<String, Object?> payload);
  Future<void> createStarpathCorrection(
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> saveStarpathDraft(
    AdminRecord record,
    Map<String, Object?> payload,
  );
  Future<void> submitStarpathRevision({
    required String revisionId,
    required String policyVersion,
  });
  Future<void> reviewStarpathRevision({
    required String revisionId,
    required StarpathReviewDiscipline discipline,
    required StarpathReviewDecision decision,
    required String reason,
  });
  Future<void> publishStarpathManifest({
    required String manifestId,
    required String reason,
  });
}
